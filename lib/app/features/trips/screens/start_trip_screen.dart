import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/config/app_config.dart';
import '../../auth/widgets/gradient_button.dart';
import '../controllers/trip_controller.dart';
import '../models/trip_model.dart';

class StartTripScreen extends StatefulWidget {
  const StartTripScreen({super.key});

  @override
  State<StartTripScreen> createState() => _StartTripScreenState();
}

class _StartTripScreenState extends State<StartTripScreen> {
  final _notesCtrl = TextEditingController();
  final _picker = ImagePicker();
  final _files = <XFile>[];

  late final TripController _tc;

  @override
  void initState() {
    super.initState();
    _tc = Get.find<TripController>();
    _tc.errorMessage.value = '';
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage(imageQuality: 70);
    if (picked.isNotEmpty) setState(() => _files.addAll(picked));
  }

  Future<void> _confirm() async {
    final success = await _tc.startTrip(
      notes: _notesCtrl.text.trim(),
      evidenceFilePaths: _files.map((f) => f.path).toList(),
    );
    if (success && mounted) Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final trip = _tc.activeTrip;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.navyBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Iniciar Viaje',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Trip summary card
            if (trip != null) _TripSummaryCard(trip: trip),
            const SizedBox(height: 20),

            // Location notice
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.lightBlue),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_rounded,
                      color: AppColors.royalBlue, size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Al iniciar el viaje se comenzará a compartir tu '
                      'ubicación en tiempo real. Asegúrate de tener el GPS '
                      'activado.',
                      style: TextStyle(
                          color: AppColors.royalBlue,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            const Text(
              'Notas de salida (opcional)',
              style: TextStyle(
                color: AppColors.navyBlue,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              style: const TextStyle(color: AppColors.textDark, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Condiciones del vehículo, observaciones...',
                hintStyle: const TextStyle(
                    color: AppColors.textLight, fontSize: 13),
                filled: true,
                fillColor: AppColors.fieldFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.fieldBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.fieldBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: AppColors.royalBlue, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 22),

            // Evidence picker
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Evidencia fotográfica',
                  style: TextStyle(
                    color: AppColors.navyBlue,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.add_photo_alternate_rounded,
                      size: 18),
                  label: const Text('Agregar'),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.royalBlue),
                ),
              ],
            ),
            if (_files.isNotEmpty) ...[
              const SizedBox(height: 8),
              _EvidencePreview(
                files: _files,
                onRemove: (i) => setState(() => _files.removeAt(i)),
              ),
            ],
            const SizedBox(height: 30),

            // Error
            Obx(() {
              final err = _tc.errorMessage.value;
              if (err.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _ErrorRow(err),
              );
            }),

            // Confirm
            Obx(() => GradientButton(
                  label: 'Confirmar inicio de viaje',
                  isLoading: _tc.isChangingStatus.value,
                  onPressed:
                      _tc.isChangingStatus.value ? null : _confirm,
                )),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Get.back(),
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

// ── Change-Status screen ─────────────────────────────────────────────────────

class ChangeStatusScreen extends StatefulWidget {
  const ChangeStatusScreen({super.key});

  @override
  State<ChangeStatusScreen> createState() => _ChangeStatusScreenState();
}

class _ChangeStatusScreenState extends State<ChangeStatusScreen> {
  final _notesCtrl = TextEditingController();
  final _picker = ImagePicker();
  final _files = <XFile>[];

  late final TripController _tc;

  @override
  void initState() {
    super.initState();
    _tc = Get.find<TripController>();
    _tc.errorMessage.value = '';
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage(imageQuality: 70);
    if (picked.isNotEmpty) setState(() => _files.addAll(picked));
  }

  Future<void> _confirmFinish() async {
    final confirmed = await _showConfirmDialog();
    if (confirmed != true) return;

    final success = await _tc.finishTrip(
      notes: _notesCtrl.text.trim(),
      evidenceFilePaths: _files.map((f) => f.path).toList(),
    );
    if (success && mounted) Get.back();
  }

  Future<bool?> _showConfirmDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Finalizar viaje',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
          '¿Confirmas que el viaje ha concluido? Se detendrá el '
          'seguimiento de ubicación.',
          style: TextStyle(color: AppColors.textMedium),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar',
                style: TextStyle(color: AppColors.textLight)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.royalBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Finalizar',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trip = _tc.activeTrip;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.navyBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Finalizar Viaje',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (trip != null) _TripSummaryCard(trip: trip),
            const SizedBox(height: 22),
            const Text(
              'Notas de llegada (opcional)',
              style: TextStyle(
                  color: AppColors.navyBlue,
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              style: const TextStyle(color: AppColors.textDark, fontSize: 14),
              decoration: InputDecoration(
                hintText:
                    'Observaciones al cierre del viaje...',
                hintStyle: const TextStyle(
                    color: AppColors.textLight, fontSize: 13),
                filled: true,
                fillColor: AppColors.fieldFill,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.fieldBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.fieldBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: AppColors.royalBlue, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Evidencia fotográfica',
                  style: TextStyle(
                      color: AppColors.navyBlue,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
                TextButton.icon(
                  onPressed: _pickImages,
                  icon: const Icon(Icons.add_photo_alternate_rounded,
                      size: 18),
                  label: const Text('Agregar'),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.royalBlue),
                ),
              ],
            ),
            if (_files.isNotEmpty) ...[
              const SizedBox(height: 8),
              _EvidencePreview(
                files: _files,
                onRemove: (i) => setState(() => _files.removeAt(i)),
              ),
            ],
            const SizedBox(height: 30),
            Obx(() {
              final err = _tc.errorMessage.value;
              if (err.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _ErrorRow(err),
              );
            }),
            Obx(() => GradientButton(
                  label: 'Finalizar viaje',
                  isLoading: _tc.isChangingStatus.value,
                  onPressed:
                      _tc.isChangingStatus.value ? null : _confirmFinish,
                )),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Get.back(),
                child: const Text('Cancelar',
                    style: TextStyle(color: AppColors.textMedium)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

class _TripSummaryCard extends StatelessWidget {
  final TripModel trip;
  const _TripSummaryCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F7FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.fieldBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_shipping_rounded,
                  color: AppColors.royalBlue, size: 18),
              const SizedBox(width: 8),
              Text(
                'Unidad ${trip.truckboxNum}',
                style: const TextStyle(
                    color: AppColors.navyBlue,
                    fontWeight: FontWeight.w700,
                    fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Expanded(
                child: Text('Origen',
                    style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 11,
                        fontWeight: FontWeight.w500)),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Destino',
                    textAlign: TextAlign.end,
                    style: TextStyle(
                        color: AppColors.textLight,
                        fontSize: 11,
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: Text(trip.origin,
                    style: const TextStyle(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ),
              const Icon(Icons.arrow_forward_rounded,
                  color: AppColors.royalBlue, size: 16),
              Expanded(
                child: Text(trip.destination,
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EvidencePreview extends StatelessWidget {
  final List<XFile> files;
  final void Function(int) onRemove;
  const _EvidencePreview({required this.files, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: files.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.file(
                File(files[i].path),
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 80,
                  height: 80,
                  color: AppColors.fieldFill,
                  child: const Icon(Icons.image_outlined,
                      color: AppColors.textLight),
                ),
              ),
            ),
            Positioned(
              top: 2,
              right: 2,
              child: GestureDetector(
                onTap: () => onRemove(i),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.errorRed,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorRow extends StatelessWidget {
  final String message;
  const _ErrorRow(this.message);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEF9A9A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppColors.errorRed, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: const TextStyle(
                    color: AppColors.errorRed,
                    fontSize: 13,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
