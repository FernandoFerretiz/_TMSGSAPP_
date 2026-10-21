import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:get/get.dart';

import '../core/config/app_config.dart';
import '../core/share/share_channel.dart';
import '../core/share/share_service.dart';

/// SultanX's own "share to" picker: only WhatsApp and Telegram, no system
/// share sheet with Instagram/Gmail/Drive/etc. Adding a future channel only
/// requires a new [ShareChannel] case — this widget stays unchanged.
///
/// The user always fires the final send from inside WhatsApp/Telegram
/// itself; this dialog only hands the file over to the chosen app.
class SultanShareDialog extends StatefulWidget {
  // Exactly one of these is set — see the named constructors below. Kept as
  // a single list internally so _onChannelTap doesn't need to branch (an
  // empty list means text-only, see SultanShareDialog.textOnly).
  final List<File> files;
  final String? text;
  final String title;
  final ShareService shareService;

  SultanShareDialog({
    super.key,
    required File file,
    this.text,
    this.title = 'Compartir evidencia',
    ShareService? shareService,
  })  : files = [file],
        shareService = shareService ?? ShareService();

  /// Shares several files as a single message when possible (see
  /// ShareService.shareFilesToChannel — Android only; iOS falls back to the
  /// first file, same one-at-a-time behavior as sharing a single [file]).
  SultanShareDialog.multi({
    super.key,
    required this.files,
    this.text,
    this.title = 'Compartir evidencia',
    ShareService? shareService,
  }) : shareService = shareService ?? ShareService();

  /// Shares [text] with no file attached (see ShareService.shareTextToChannel).
  SultanShareDialog.textOnly({
    super.key,
    required this.text,
    this.title = 'Compartir resumen',
    ShareService? shareService,
  })  : files = const [],
        shareService = shareService ?? ShareService();

  static Future<void> show(
    BuildContext context, {
    required File file,
    String? text,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SultanShareDialog(file: file, text: text),
    );
  }

  static Future<void> showMulti(
    BuildContext context, {
    required List<File> files,
    String? text,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SultanShareDialog.multi(files: files, text: text),
    );
  }

  static Future<void> showTextOnly(
    BuildContext context, {
    required String text,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SultanShareDialog.textOnly(text: text),
    );
  }

  @override
  State<SultanShareDialog> createState() => _SultanShareDialogState();
}

class _SultanShareDialogState extends State<SultanShareDialog> {
  Map<ShareChannel, bool> _availability = {};
  ShareChannel? _sharingChannel;
  bool _checkingAvailability = true;

  @override
  void initState() {
    super.initState();
    _checkAvailability();
  }

  Future<void> _checkAvailability() async {
    final results = <ShareChannel, bool>{};
    for (final channel in ShareChannel.values) {
      results[channel] = await widget.shareService.isChannelInstalled(
        channel,
      );
    }
    if (!mounted) return;
    setState(() {
      _availability = results;
      _checkingAvailability = false;
    });
  }

  Future<void> _onChannelTap(ShareChannel channel) async {
    if (_availability[channel] != true || _sharingChannel != null) return;

    setState(() => _sharingChannel = channel);
    final result = widget.files.isEmpty
        ? await widget.shareService.shareTextToChannel(
            channel,
            text: widget.text ?? '',
          )
        : await widget.shareService.shareFilesToChannel(
            channel,
            files: widget.files,
            text: widget.text,
          );

    if (!mounted) return;

    if (result.success) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _sharingChannel = null);
    Get.snackbar(
      '${channel.label} no disponible',
      result.errorMessage ?? 'No se pudo compartir el archivo.',
      backgroundColor: AppColors.errorRed,
      colorText: Colors.white,
    );
  }

  // Solo copia el texto (no hay forma útil de "copiar" un archivo binario al
  // portapapeles) — cubre los usos reales hasta ahora, que siempre traen
  // texto (resumen del historial, datos para fianza), aunque también
  // adjunten fotos.
  bool get _canCopy => (widget.text ?? '').trim().isNotEmpty;

  Future<void> _onCopyTap() async {
    if (!_canCopy) return;
    await Clipboard.setData(ClipboardData(text: widget.text!));
    if (!mounted) return;
    Navigator.of(context).pop();
    Get.snackbar(
      'Copiado',
      'El texto se copió al portapapeles.',
      backgroundColor: AppColors.royalBlue,
      colorText: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.fieldBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              widget.title,
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            if (_checkingAvailability)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(color: AppColors.royalBlue),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (final channel in ShareChannel.values) ...[
                    _ActionButton(
                      icon: channel.icon,
                      label: channel.label,
                      color: channel.brandColor,
                      installed: _availability[channel] ?? false,
                      isLoading: _sharingChannel == channel,
                      onTap: () => _onChannelTap(channel),
                    ),
                    const SizedBox(width: 28),
                  ],
                  _ActionButton(
                    icon: Icons.copy_rounded,
                    label: 'Copiar',
                    color: AppColors.royalBlue,
                    installed: _canCopy,
                    isLoading: false,
                    onTap: _onCopyTap,
                  ),
                ],
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: AppColors.textMedium),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Generic destination tile: one of the [ShareChannel]s, or the "copiar al
/// portapapeles" option — same look either way.
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool installed;
  final bool isLoading;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.installed,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = installed ? color : AppColors.textLight;

    return Opacity(
      opacity: installed ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: installed ? onTap : null,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: effectiveColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: isLoading
                      ? Padding(
                          padding: const EdgeInsets.all(16),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: effectiveColor,
                          ),
                        )
                      : Icon(icon, color: effectiveColor, size: 26),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: installed ? AppColors.textDark : AppColors.textLight,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!installed) ...[
                  const SizedBox(height: 2),
                  const Text(
                    'No disponible',
                    style: TextStyle(
                      color: AppColors.textLight,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
