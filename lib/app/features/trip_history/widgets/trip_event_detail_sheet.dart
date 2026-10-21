import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../core/config/app_config.dart';
import '../../../core/files/remote_file_downloader.dart';
import '../../../core/network/api_client.dart';
import '../../../shared_components/sultan_share_dialog.dart';
import '../models/trip_event.dart';
import '../models/trip_evidence_file.dart';
import '../models/trip_summary.dart';
import '../utils/trip_event_share_templates.dart';
import 'evidence_carousel_viewer.dart';
import 'status_badge.dart';

/// Full detail of a single timeline event (status change or incident):
/// comments, checklist answers, seal, evidence. Sharing is split in two
/// independent actions — "Compartir resumen" (just the composed text, see
/// trip_event_share_templates.dart) and "Compartir evidencia" (whichever
/// photos the user checks in the gallery below, viewable full-screen via
/// EvidenceCarouselViewer).
class TripEventDetailSheet extends StatefulWidget {
  final TripSummary trip;
  final TripEvent event;

  const TripEventDetailSheet({
    super.key,
    required this.trip,
    required this.event,
  });

  static Future<void> show(
    BuildContext context, {
    required TripSummary trip,
    required TripEvent event,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => TripEventDetailSheet(trip: trip, event: event),
    );
  }

  @override
  State<TripEventDetailSheet> createState() => _TripEventDetailSheetState();
}

class _TripEventDetailSheetState extends State<TripEventDetailSheet> {
  // Defaults to "all selected" — matches the old behavior (send everything)
  // while letting the operator uncheck what they don't want to send.
  late Set<int> _selected =
      Set<int>.from(List.generate(widget.event.files.length, (i) => i));

  bool get _isIncident => widget.event.type == TripEventType.incident;

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final trip = widget.trip;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => SafeArea(
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.fieldBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            _Header(event: event),
            const SizedBox(height: 16),
            if (event.subtitle != null && event.subtitle!.trim().isNotEmpty)
              _Section(
                title: _isIncident ? 'Comentarios del operador' : 'Notas',
                child: Text(
                  event.subtitle!.trim(),
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
            if (event.extraFields.isNotEmpty)
              _Section(
                title: 'Detalles',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: event.extraFields
                      .map((f) => _KeyValueRow(label: f.label, value: f.value))
                      .toList(),
                ),
              ),
            if (event.canContinueTrip != null)
              _Section(
                title: '¿Puede continuar el viaje?',
                child: Text(
                  event.canContinueTrip! ? 'Sí' : 'No',
                  style: TextStyle(
                    color: event.canContinueTrip!
                        ? const Color(0xFF2E7D32)
                        : AppColors.errorRed,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (event.checklist.isNotEmpty)
              _Section(
                title: 'Checklist',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: event.checklist
                      .map((a) => _ChecklistRow(answer: a))
                      .toList(),
                ),
              ),
            if (event.sealCode != null && event.sealCode!.isNotEmpty)
              _Section(
                title: 'Sello',
                child: Text(
                  event.sealCode!,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (event.files.isNotEmpty)
              _Section(
                title: 'Evidencia — toca una foto para verla, marca las que quieras enviar',
                child: _EvidenceGallery(
                  files: event.files,
                  selected: _selected,
                  onToggle: (i) => setState(() {
                    if (_selected.contains(i)) {
                      _selected.remove(i);
                    } else {
                      _selected.add(i);
                    }
                  }),
                ),
              ),
            const SizedBox(height: 12),
            _ShareTextButton(trip: trip, event: event),
            const SizedBox(height: 10),
            _ShareEvidenceButton(
              files: event.files,
              selected: _selected,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final TripEvent event;
  const _Header({required this.event});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.title,
                style: const TextStyle(
                  color: AppColors.navyBlue,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  if (event.actorName != null &&
                      event.actorName!.trim().isNotEmpty) ...[
                    const Icon(Icons.person_outline_rounded,
                        size: 14, color: AppColors.textLight),
                    const SizedBox(width: 4),
                    Text(
                      event.actorName!,
                      style: const TextStyle(
                          color: AppColors.textLight, fontSize: 12.5),
                    ),
                    const SizedBox(width: 10),
                  ],
                  if (event.timestamp != null) ...[
                    const Icon(Icons.access_time_rounded,
                        size: 14, color: AppColors.textLight),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat("d MMM, HH:mm").format(event.timestamp!),
                      style: const TextStyle(
                          color: AppColors.textLight, fontSize: 12.5),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        if (event.statusCode != null)
          StatusBadge(
            code: event.statusCode!,
            label: event.title.replaceFirst('Cambio de estado: ', ''),
            compact: true,
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppColors.textLight,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  final String label;
  final String value;
  const _KeyValueRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 14, color: AppColors.textDark),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  final TripEventChecklistAnswer answer;
  const _ChecklistRow({required this.answer});

  @override
  Widget build(BuildContext context) {
    final isNo = answer.answer.trim().toLowerCase() == 'no';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isNo ? Icons.cancel_rounded : Icons.check_circle_rounded,
                size: 16,
                color: isNo ? AppColors.errorRed : const Color(0xFF2E7D32),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${answer.prompt}: ${answer.answer}'
                  '${(answer.detail?.isNotEmpty ?? false) ? ' (${answer.detail})' : ''}',
                  style: const TextStyle(
                      color: AppColors.textDark, fontSize: 13.5),
                ),
              ),
            ],
          ),
          if (answer.photos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 24, top: 4),
              child: Wrap(
                spacing: 6,
                children: answer.photos
                    .map((p) => Icon(Icons.image_outlined,
                        size: 16, color: AppColors.royalBlue))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

/// Grid of evidence thumbnails: tap the photo to open it full-screen in
/// EvidenceCarouselViewer, tap the checkbox to include/exclude it from
/// "Compartir evidencia".
class _EvidenceGallery extends StatelessWidget {
  final List<TripEvidenceFile> files;
  final Set<int> selected;
  final ValueChanged<int> onToggle;

  const _EvidenceGallery({
    required this.files,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(files.length, (i) {
        return _EvidenceThumb(
          file: files[i],
          isSelected: selected.contains(i),
          onTapImage: () => EvidenceCarouselViewer.show(
            context,
            files: files,
            initialIndex: i,
          ),
          onToggleSelected: () => onToggle(i),
        );
      }),
    );
  }
}

class _EvidenceThumb extends StatefulWidget {
  final TripEvidenceFile file;
  final bool isSelected;
  final VoidCallback onTapImage;
  final VoidCallback onToggleSelected;

  const _EvidenceThumb({
    required this.file,
    required this.isSelected,
    required this.onTapImage,
    required this.onToggleSelected,
  });

  @override
  State<_EvidenceThumb> createState() => _EvidenceThumbState();
}

class _EvidenceThumbState extends State<_EvidenceThumb> {
  late final _downloader = RemoteFileDownloader(Get.find<ApiClient>().dio);
  Future<File>? _future;

  @override
  void initState() {
    super.initState();
    if (widget.file.isImage) {
      _future = _downloader.download(widget.file.url, widget.file.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTapImage,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 84,
              height: 84,
              color: AppColors.fieldFill,
              child: _future == null
                  ? Icon(Icons.insert_drive_file_outlined,
                      color: AppColors.royalBlue, size: 28)
                  : FutureBuilder<File>(
                      future: _future,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          );
                        }
                        if (!snapshot.hasData) {
                          return const Icon(Icons.broken_image_outlined,
                              color: AppColors.textLight);
                        }
                        return Image.file(snapshot.data!, fit: BoxFit.cover);
                      },
                    ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: widget.onToggleSelected,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isSelected
                      ? AppColors.royalBlue
                      : Colors.black.withValues(alpha: 0.45),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Icon(
                  widget.isSelected ? Icons.check_rounded : null,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shares just the composed text for [event] — no evidence attached.
class _ShareTextButton extends StatelessWidget {
  final TripSummary trip;
  final TripEvent event;
  const _ShareTextButton({required this.trip, required this.event});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => SultanShareDialog.showTextOnly(
          context,
          text: shareTextFor(trip, event),
        ),
        icon: const Icon(Icons.share_rounded),
        label: const Text('Compartir resumen'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.royalBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

/// Shares whichever evidence photos are checked in [_EvidenceGallery] — no
/// text attached, the summary already went (or can go) separately.
class _ShareEvidenceButton extends StatefulWidget {
  final List<TripEvidenceFile> files;
  final Set<int> selected;
  const _ShareEvidenceButton({required this.files, required this.selected});

  @override
  State<_ShareEvidenceButton> createState() => _ShareEvidenceButtonState();
}

class _ShareEvidenceButtonState extends State<_ShareEvidenceButton> {
  late final _downloader = RemoteFileDownloader(Get.find<ApiClient>().dio);
  bool _preparing = false;

  Future<void> _handleTap() async {
    final chosen = widget.selected.toList()..sort();
    if (chosen.isEmpty || _preparing) return;

    setState(() => _preparing = true);
    try {
      final files = await Future.wait(chosen.map((i) {
        final f = widget.files[i];
        return _downloader.download(f.url, f.name);
      }));
      if (!mounted) return;
      await SultanShareDialog.showMulti(context, files: files);
    } catch (_) {
      if (!mounted) return;
      Get.snackbar(
        'No se pudo preparar la evidencia',
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
    final count = widget.selected.length;
    final hasFiles = widget.files.isNotEmpty;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: (!hasFiles || count == 0 || _preparing) ? null : _handleTap,
        icon: _preparing
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.photo_library_outlined),
        label: Text(
          !hasFiles
              ? 'Sin evidencia para compartir'
              : count == 0
                  ? 'Selecciona al menos una foto'
                  : 'Compartir evidencia ($count)',
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.royalBlue,
          side: const BorderSide(color: AppColors.royalBlue),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
