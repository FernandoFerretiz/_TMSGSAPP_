package com.sultanx.tms

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.UUID

/**
 * Bridges ShareService (lib/app/core/share/share_service.dart) and
 * ReceiveShareService (lib/app/core/share/receive_share_service.dart) to
 * native Android sharing:
 *  - Outgoing: ACTION_SEND targeted at a single app via setPackage(), so
 *    evidence files go straight to WhatsApp/Telegram instead of the
 *    generic share sheet.
 *  - Incoming: SultanX shows up as a share target from other apps (see the
 *    SEND intent-filter in AndroidManifest.xml); received files are copied
 *    into our cache dir and handed to Dart.
 */
class MainActivity : FlutterActivity() {
    private val shareChannelName = "com.sultanx.tms/share"
    private val shareEventsChannelName = "com.sultanx.tms/share_events"

    private var pendingSharedFile: Map<String, Any?>? = null
    private var shareEventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, shareChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAppInstalled" -> {
                        val candidates = call.argument<List<String>>("packages") ?: emptyList()
                        result.success(resolveInstalledPackage(candidates) != null)
                    }

                    "shareFile" -> {
                        val candidates = call.argument<List<String>>("packages") ?: emptyList()
                        val filePath = call.argument<String>("filePath")
                        val mimeType = call.argument<String>("mimeType") ?: "*/*"
                        val text = call.argument<String>("text")

                        val targetPackage = resolveInstalledPackage(candidates)

                        if (targetPackage == null || filePath == null) {
                            result.success(false)
                            return@setMethodCallHandler
                        }

                        try {
                            shareFileToPackage(targetPackage, filePath, mimeType, text)
                            result.success(true)
                        } catch (e: ActivityNotFoundException) {
                            result.success(false)
                        } catch (e: Exception) {
                            result.error("SHARE_FAILED", e.message, null)
                        }
                    }

                    "shareFiles" -> {
                        val candidates = call.argument<List<String>>("packages") ?: emptyList()
                        val filePaths = call.argument<List<String>>("filePaths") ?: emptyList()
                        val mimeType = call.argument<String>("mimeType") ?: "*/*"
                        val text = call.argument<String>("text")

                        val targetPackage = resolveInstalledPackage(candidates)

                        if (targetPackage == null || filePaths.isEmpty()) {
                            result.success(false)
                            return@setMethodCallHandler
                        }

                        try {
                            shareFilesToPackage(targetPackage, filePaths, mimeType, text)
                            result.success(true)
                        } catch (e: ActivityNotFoundException) {
                            result.success(false)
                        } catch (e: Exception) {
                            result.error("SHARE_FAILED", e.message, null)
                        }
                    }

                    "shareText" -> {
                        val candidates = call.argument<List<String>>("packages") ?: emptyList()
                        val text = call.argument<String>("text")

                        val targetPackage = resolveInstalledPackage(candidates)

                        if (targetPackage == null || text.isNullOrEmpty()) {
                            result.success(false)
                            return@setMethodCallHandler
                        }

                        try {
                            shareTextToPackage(targetPackage, text)
                            result.success(true)
                        } catch (e: ActivityNotFoundException) {
                            result.success(false)
                        } catch (e: Exception) {
                            result.error("SHARE_FAILED", e.message, null)
                        }
                    }

                    "takePendingSharedFile" -> {
                        result.success(pendingSharedFile)
                        pendingSharedFile = null
                    }

                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, shareEventsChannelName)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    shareEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    shareEventSink = null
                }
            })

        // Cold start: the app was launched directly by the SEND intent —
        // no Dart listener exists yet, so just stash it for takePendingSharedFile.
        handleIncomingIntent(intent, notifyFlutter = false)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        // App was already running (singleTop) — push it straight to Dart.
        handleIncomingIntent(intent, notifyFlutter = true)
    }

    // ── Receiving shares from other apps (WhatsApp, Galería, Archivos…) ────
    //
    // The incoming content:// URI is only valid for the lifetime of this
    // intent/grant, so we copy its bytes into our own cache dir right away
    // and hand Flutter a plain file path instead.
    private fun handleIncomingIntent(intent: Intent?, notifyFlutter: Boolean) {
        if (intent == null || intent.action != Intent.ACTION_SEND) return

        val uri = getStreamExtra(intent) ?: return
        val mimeType = intent.type ?: "application/octet-stream"
        val text = intent.getStringExtra(Intent.EXTRA_TEXT)

        val file = copyToCache(uri) ?: return
        val payload = mapOf(
            "filePath" to file.absolutePath,
            "mimeType" to mimeType,
            "text" to text,
        )

        // Consume this intent's extras once — a stale onNewIntent replay
        // (e.g. after a config change) shouldn't re-trigger the same share.
        intent.action = null

        if (notifyFlutter && shareEventSink != null) {
            shareEventSink?.success(payload)
        } else {
            pendingSharedFile = payload
        }
    }

    @Suppress("DEPRECATION")
    private fun getStreamExtra(intent: Intent): Uri? = if (Build.VERSION.SDK_INT >= 33) {
        intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
    } else {
        intent.getParcelableExtra(Intent.EXTRA_STREAM)
    }

    private fun copyToCache(uri: Uri): File? {
        return try {
            val name = queryDisplayName(uri) ?: "shared_${UUID.randomUUID()}"
            val dir = File(cacheDir, "incoming_shares").apply { mkdirs() }
            val target = File(dir, name)

            val copied = contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(target).use { output -> input.copyTo(output) }
                true
            } ?: false

            if (copied) target else null
        } catch (e: Exception) {
            null
        }
    }

    private fun queryDisplayName(uri: Uri): String? {
        return try {
            contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index >= 0 && cursor.moveToFirst()) cursor.getString(index) else null
            }
        } catch (e: Exception) {
            null
        }
    }

    // ── Sending a file to a single app ──────────────────────────────────

    // Relies on the <queries> block in AndroidManifest.xml — without it,
    // Android 11+ package visibility rules hide other apps' packages from
    // getLaunchIntentForPackage() regardless of whether they're installed.
    //
    // A channel may ship under more than one applicationId in the wild
    // (e.g. Telegram builds distributed outside the Play Store) — the first
    // candidate that resolves to an installed app wins.
    private fun resolveInstalledPackage(candidates: List<String>): String? =
        candidates.firstOrNull { packageManager.getLaunchIntentForPackage(it) != null }

    private fun shareFileToPackage(
        targetPackage: String,
        filePath: String,
        mimeType: String,
        text: String?,
    ) {
        val file = File(filePath)
        val uri: Uri = FileProvider.getUriForFile(this, "$packageName.shareprovider", file)

        val intent = Intent(Intent.ACTION_SEND).apply {
            `package` = targetPackage
            type = mimeType
            putExtra(Intent.EXTRA_STREAM, uri)
            if (!text.isNullOrEmpty()) {
                putExtra(Intent.EXTRA_TEXT, text)
            }
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        startActivity(intent)
    }

    // ── Sending several files to a single app at once ──────────────────
    //
    // ACTION_SEND_MULTIPLE (vs. ACTION_SEND) is what lets WhatsApp/Telegram
    // receive a whole batch as one message instead of the user having to
    // repeat the share once per file — only available on Android; iOS'
    // UIDocumentInteractionController (see AppDelegate.swift) has no
    // multi-file equivalent, so that side keeps sharing one at a time.
    private fun shareFilesToPackage(
        targetPackage: String,
        filePaths: List<String>,
        mimeType: String,
        text: String?,
    ) {
        val uris = ArrayList(filePaths.map { path ->
            FileProvider.getUriForFile(this, "$packageName.shareprovider", File(path))
        })

        val intent = Intent(Intent.ACTION_SEND_MULTIPLE).apply {
            `package` = targetPackage
            type = mimeType
            putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)
            if (!text.isNullOrEmpty()) {
                putExtra(Intent.EXTRA_TEXT, text)
            }
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        startActivity(intent)
    }

    // ── Sending text only, no file (e.g. "Compartir resumen" without any
    // evidence attached) — same ACTION_SEND + setPackage targeting as the
    // file variants above, just without EXTRA_STREAM.
    private fun shareTextToPackage(targetPackage: String, text: String) {
        val intent = Intent(Intent.ACTION_SEND).apply {
            `package` = targetPackage
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, text)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }

        startActivity(intent)
    }
}
