import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/config/app_config.dart';
import '../../../core/files/remote_file_downloader.dart';
import '../../../core/network/api_client.dart';
import '../../../shared_components/sultan_share_dialog.dart';
import '../models/trip_evidence_file.dart';

/// Downloads a trip's remote evidence file into a local cache file and
/// opens [SultanShareDialog] on it. Kept separate from [SultanShareDialog]
/// itself so that widget stays generic (it only ever deals with a local
/// [File], never a URL or the network).
class EvidenceShareButton extends StatefulWidget {
  final TripEvidenceFile evidenceFile;
  final String? message;

  const EvidenceShareButton({
    super.key,
    required this.evidenceFile,
    this.message,
  });

  @override
  State<EvidenceShareButton> createState() => _EvidenceShareButtonState();
}

class _EvidenceShareButtonState extends State<EvidenceShareButton> {
  late final _downloader = RemoteFileDownloader(Get.find<ApiClient>().dio);
  bool _preparing = false;

  Future<void> _handleTap() async {
    if (_preparing) return;
    setState(() => _preparing = true);
    try {
      final file = await _downloader.download(
        widget.evidenceFile.url,
        widget.evidenceFile.name,
      );
      if (!mounted) return;
      await SultanShareDialog.show(context, file: file, text: widget.message);
    } catch (_) {
      if (!mounted) return;
      Get.snackbar(
        'No se pudo preparar el archivo',
        'Revisa tu conexión e inténtalo de nuevo.',
        backgroundColor: AppColors.errorRed,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: _preparing ? null : _handleTap,
      visualDensity: VisualDensity.compact,
      icon: _preparing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.royalBlue,
              ),
            )
          : const Icon(
              Icons.share_rounded,
              color: AppColors.royalBlue,
              size: 20,
            ),
      tooltip: 'Compartir',
    );
  }
}
