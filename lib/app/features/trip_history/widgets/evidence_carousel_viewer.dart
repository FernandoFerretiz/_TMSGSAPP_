import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/files/remote_file_downloader.dart';
import '../../../core/network/api_client.dart';
import '../models/trip_evidence_file.dart';

/// Full-screen swipeable viewer for an event's evidence photos — opened by
/// tapping a thumbnail in the "Evidencia" section of TripEventDetailSheet.
class EvidenceCarouselViewer extends StatefulWidget {
  final List<TripEvidenceFile> files;
  final int initialIndex;

  const EvidenceCarouselViewer({
    super.key,
    required this.files,
    this.initialIndex = 0,
  });

  static Future<void> show(
    BuildContext context, {
    required List<TripEvidenceFile> files,
    int initialIndex = 0,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) =>
            EvidenceCarouselViewer(files: files, initialIndex: initialIndex),
      ),
    );
  }

  @override
  State<EvidenceCarouselViewer> createState() => _EvidenceCarouselViewerState();
}

class _EvidenceCarouselViewerState extends State<EvidenceCarouselViewer> {
  late final _downloader = RemoteFileDownloader(Get.find<ApiClient>().dio);
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.files.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (context, i) => _EvidencePage(
                file: widget.files[i],
                downloader: _downloader,
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            if (widget.files.length > 1)
              Positioned(
                top: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_index + 1} / ${widget.files.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EvidencePage extends StatefulWidget {
  final TripEvidenceFile file;
  final RemoteFileDownloader downloader;
  const _EvidencePage({required this.file, required this.downloader});

  @override
  State<_EvidencePage> createState() => _EvidencePageState();
}

class _EvidencePageState extends State<_EvidencePage> {
  late final Future<File> _future =
      widget.downloader.download(widget.file.url, widget.file.name);

  @override
  Widget build(BuildContext context) {
    if (!widget.file.isImage) {
      return _NonImagePlaceholder(file: widget.file);
    }

    return FutureBuilder<File>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return const Center(
            child: Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
          );
        }
        return InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Center(
            child: Image.file(snapshot.data!, fit: BoxFit.contain),
          ),
        );
      },
    );
  }
}

class _NonImagePlaceholder extends StatelessWidget {
  final TripEvidenceFile file;
  const _NonImagePlaceholder({required this.file});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.insert_drive_file_outlined, color: Colors.white54, size: 56),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              file.label ?? file.name,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Este archivo no se puede previsualizar aquí',
            style: TextStyle(color: Colors.white38, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}
