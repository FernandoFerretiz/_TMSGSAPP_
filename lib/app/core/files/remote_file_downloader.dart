import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

/// Downloads a remote evidence/document URL into the app's cache dir so it
/// can be handed to WhatsApp/Telegram as a real file attachment (sharing a
/// bare URL is not acceptable for this feature). Results are cached by file
/// name for the lifetime of the app's cache.
///
/// Evidence URLs returned by the backend are relative paths (e.g.
/// `/api/mobile/files/<uuid>`), served behind Sanctum auth on the same
/// host as the rest of the API. Callers must pass the app's shared
/// [ApiClient.dio] (baseUrl + auth token already wired in) — a bare `Dio()`
/// cannot resolve or authenticate these requests.
class RemoteFileDownloader {
  final Dio _dio;

  RemoteFileDownloader(Dio dio) : _dio = dio;

  Future<File> download(String url, String fileName) async {
    final dir = await getTemporaryDirectory();
    final shareDir = Directory('${dir.path}/share_cache');
    if (!await shareDir.exists()) {
      await shareDir.create(recursive: true);
    }

    // Keyed by url hash + name: evidence files routinely share the same
    // original_name (e.g. camera photos all named "image.jpg"), so keying
    // by name alone collided different files onto the same cached path —
    // every thumbnail/share ended up reusing whichever file downloaded
    // first.
    final key = url.hashCode.toRadixString(16);
    final file = File('${shareDir.path}/${key}_${_sanitize(fileName)}');
    if (await file.exists()) return file;

    final response = await _dio.get<List<int>>(
      url,
      options: Options(responseType: ResponseType.bytes),
    );
    await file.writeAsBytes(response.data!);
    return file;
  }

  String _sanitize(String name) => name.replaceAll(RegExp(r'[/\\]'), '_');
}
