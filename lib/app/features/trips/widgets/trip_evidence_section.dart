import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/config/app_config.dart';
import '../controllers/trip_controller.dart';
import '../models/trip_evidence_state.dart';
import 'evidence_style.dart';

/// Carga de evidencias de una etapa del viaje (inicio o final), con el mismo
/// diseño y funcionamiento que la página web de evidencias: tarjetas de
/// carga que suben al instante, visor/borrado de archivos, código del sello
/// y checklist en la misma pantalla.
class TripEvidenceSection extends StatefulWidget {
  final TripController tc;
  const TripEvidenceSection({super.key, required this.tc});

  @override
  State<TripEvidenceSection> createState() => _TripEvidenceSectionState();
}

class _TripEvidenceSectionState extends State<TripEvidenceSection> {
  TripController get tc => widget.tc;

  @override
  void initState() {
    super.initState();
    // Diferido: se limpia el estado de la etapa anterior (inicio -> final)
    // sin mutar Rx durante el build de la pantalla que nos abre.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      tc.evidence.value = null;
      tc.loadEvidence();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final state = tc.evidence.value;
      final busy = tc.isEvidenceBusy.value;
      final error = tc.evidenceError.value;

      if (state == null) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: error.isEmpty
                ? const CircularProgressIndicator(color: AppColors.royalBlue)
                : Column(
                    children: [
                      Text(error,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: AppColors.errorRed, fontSize: 13)),
                      TextButton(
                          onPressed: tc.loadEvidence,
                          child: const Text('Reintentar')),
                    ],
                  ),
          ),
        );
      }

      final cards = _cardsFor(state);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (busy)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: LinearProgressIndicator(
                  minHeight: 3, color: AppColors.royalBlue),
            ),
          for (final card in cards) ...[
            card,
            const SizedBox(height: 10),
          ],
          if (state.sealActive) ...[
            _SealCodeBox(tc: tc, initial: state.sealCode),
            const SizedBox(height: 12),
          ],
          if (state.questions.isNotEmpty) ...[
            _ChecklistBox(tc: tc, state: state),
            const SizedBox(height: 12),
          ],
          if (error.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(error,
                  style: const TextStyle(
                      color: AppColors.errorRed,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600)),
            ),
        ],
      );
    });
  }

  List<Widget> _cardsFor(TripEvidenceState state) {
    Widget card({
      required String kind,
      required IconData icon,
      required String title,
      required String description,
      required String actionEmpty,
      String actionMore = 'Agregar más',
      bool allowPdf = false,
      bool single = false,
      bool required = false,
    }) {
      final count = state.count(kind);
      return _UploadCard(
        icon: icon,
        title: title,
        description: description,
        actionLabel: count == 0 ? actionEmpty : (single ? 'Cambiar foto' : actionMore),
        count: count,
        required: required,
        enabled: state.canUpload,
        onUpload: () => _pickAndUpload(kind, allowPdf: allowPdf, single: single),
        onView: count == 0 ? null : () => _showFiles(kind, title),
      );
    }

    if (state.isStart) {
      return [
        card(
          kind: TripEvidenceState.startPhotos,
          icon: Icons.photo_camera_rounded,
          title: 'Fotos de inicio',
          description: 'Caja, llantas, placas, puertas y condiciones generales.',
          actionEmpty: 'Tomar / seleccionar fotos',
        ),
        card(
          kind: TripEvidenceState.startDocs,
          icon: Icons.description_rounded,
          title: 'Documentos de inicio',
          description: 'Documentos entregados o generados al iniciar el viaje.',
          actionEmpty: 'Subir documentos',
          allowPdf: true,
        ),
        if (state.sealActive && state.sealKind == TripEvidenceState.sealPhoto)
          card(
            kind: TripEvidenceState.sealPhoto,
            icon: Icons.lock_rounded,
            title: 'Foto del candado / sello',
            description: 'Una foto donde se vea el sello de seguridad colocado.',
            actionEmpty: 'Tomar foto',
            single: true,
          ),
      ];
    }

    return [
      if (state.requiresEndEvidence) ...[
        if (state.requiresEndPhotos)
          card(
            kind: TripEvidenceState.endPhotos,
            icon: Icons.photo_camera_rounded,
            title: 'Fotos de finalización',
            description:
                'Caja descargada/cargada, destino y condiciones de entrega.',
            actionEmpty: 'Tomar / seleccionar fotos',
          ),
        card(
          kind: TripEvidenceState.endPod,
          icon: Icons.receipt_long_rounded,
          title: 'POD / Documento de descarga',
          description:
              'Sube el POD firmado o documento que compruebe la entrega.',
          actionEmpty: 'Subir POD',
          allowPdf: true,
          required: state.podRequired,
        ),
      ],
      if (state.sealActive && state.sealKind == TripEvidenceState.endSealPhoto)
        card(
          kind: TripEvidenceState.endSealPhoto,
          icon: Icons.lock_rounded,
          title: 'Foto del candado / sello',
          description: 'Una foto donde se vea el sello de seguridad colocado.',
          actionEmpty: 'Tomar foto',
          single: true,
        ),
    ];
  }

  Future<void> _pickAndUpload(String kind,
      {required bool allowPdf, required bool single}) async {
    final source = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.fieldBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded,
                  color: AppColors.royalBlue),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.of(ctx).pop('camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded,
                  color: AppColors.royalBlue),
              title: Text(single ? 'Elegir de galería' : 'Elegir de galería (varias)'),
              onTap: () => Navigator.of(ctx).pop('gallery'),
            ),
            if (allowPdf)
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_rounded,
                    color: AppColors.royalBlue),
                title: const Text('Archivo PDF o imagen'),
                onTap: () => Navigator.of(ctx).pop('file'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;

    final picker = ImagePicker();
    var paths = <String>[];

    if (source == 'camera') {
      final photo =
          await picker.pickImage(source: ImageSource.camera, imageQuality: 60);
      if (photo != null) paths = [photo.path];
    } else if (source == 'gallery') {
      if (single) {
        final photo = await picker.pickImage(
            source: ImageSource.gallery, imageQuality: 60);
        if (photo != null) paths = [photo.path];
      } else {
        final photos = await picker.pickMultiImage(imageQuality: 60);
        paths = photos.map((f) => f.path).toList();
      }
    } else {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'heic', 'heif', 'pdf'],
      );
      paths = result?.paths.whereType<String>().toList() ?? [];
    }

    if (paths.isEmpty) return;
    await tc.uploadEvidence(kind, paths);
  }

  void _showFiles(String kind, String title) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _FilesSheet(tc: tc, kind: kind, title: title),
    );
  }
}

class _UploadCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final int count;
  final bool required;
  final bool enabled;
  final VoidCallback onUpload;
  final VoidCallback? onView;

  const _UploadCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.count,
    required this.required,
    required this.enabled,
    required this.onUpload,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final complete = count > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: enabled ? onUpload : null,
          child: DashedRRectBorder(
            color: complete ? const Color(0xFFBBF7D0) : Ev.gray300,
            background: complete ? Ev.greenSoft : Colors.white,
            child: Container(
              constraints: const BoxConstraints(minHeight: 120),
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: complete
                          ? const Color(0xFFDCFCE7)
                          : const Color(0xFFE3EEFF),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon,
                        size: 24, color: complete ? Ev.green : Ev.orangeDark),
                  ),
                  Text(title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Ev.text,
                          fontSize: 14,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Ev.gray500, fontSize: 12, height: 1.35)),
                  const SizedBox(height: 12),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                    decoration: BoxDecoration(
                      color: complete ? Ev.green : Ev.navy,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(actionLabel,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w800)),
                  ),
                  if (required) ...[
                    const SizedBox(height: 8),
                    const Text('OBLIGATORIO',
                        style: TextStyle(
                            color: Color(0xFFDC2626),
                            fontSize: 10,
                            letterSpacing: 0.5,
                            fontWeight: FontWeight.w800)),
                  ],
                ],
              ),
            ),
          ),
        ),
        if (onView != null) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onView,
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Ev.navy,
              side: const BorderSide(color: Ev.gray200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11)),
            ),
            child: Text(
              count == 1 ? 'Ver archivo (1)' : 'Ver archivos ($count)',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ],
    );
  }
}

class _FilesSheet extends StatelessWidget {
  final TripController tc;
  final String kind;
  final String title;
  const _FilesSheet({required this.tc, required this.kind, required this.title});

  Future<void> _open(EvidenceFile file) async {
    final uri = Uri.tryParse(file.url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _confirmDelete(BuildContext context, EvidenceFile file) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Eliminar archivo',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('¿Eliminar "${file.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Eliminar',
                  style: TextStyle(color: AppColors.errorRed))),
        ],
      ),
    );
    if (ok == true) await tc.deleteEvidence(file.uuid);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
        child: Obx(() {
          final files = tc.evidence.value?.filesOf(kind) ?? const [];
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(title,
                          style: const TextStyle(
                              color: AppColors.navyBlue,
                              fontSize: 16,
                              fontWeight: FontWeight.w800)),
                    ),
                    IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.of(context).pop()),
                  ],
                ),
              ),
              if (files.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No hay archivos cargados.',
                      style: TextStyle(color: AppColors.textMedium)),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    itemCount: files.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final file = files[i];
                      return Row(
                        children: [
                          GestureDetector(
                            onTap: () => _open(file),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: 64,
                                height: 64,
                                child: file.isImage
                                    ? Image.network(file.url,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Icon(
                                            Icons.broken_image_rounded))
                                    : Container(
                                        color: const Color(0xFFFFEBEE),
                                        child: const Icon(
                                            Icons.picture_as_pdf_rounded,
                                            color: AppColors.errorRed,
                                            size: 30),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(file.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: AppColors.textDark,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ),
                          if (file.canDelete)
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded,
                                  color: AppColors.errorRed),
                              onPressed: () => _confirmDelete(context, file),
                            ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }
}

class _ExtraBox extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  const _ExtraBox(
      {required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return EvBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Ev.text, fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(subtitle,
              style: const TextStyle(color: Ev.gray500, fontSize: 12)),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

InputDecoration _fieldDecoration(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Ev.gray500, fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Ev.gray300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Ev.gray300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Ev.navy, width: 1.5),
      ),
    );

ButtonStyle _miniBtn() => ElevatedButton.styleFrom(
      backgroundColor: Ev.navy,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );

class _SealCodeBox extends StatefulWidget {
  final TripController tc;
  final String initial;
  const _SealCodeBox({required this.tc, required this.initial});

  @override
  State<_SealCodeBox> createState() => _SealCodeBoxState();
}

class _SealCodeBoxState extends State<_SealCodeBox> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ExtraBox(
      title: '🔒 Código del candado / sello',
      subtitle: 'Escribe el código del sello de seguridad colocado en la unidad.',
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              maxLength: 100,
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
              decoration: _fieldDecoration('Código del sello'),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () async {
              final code = _ctrl.text.trim();
              if (code.isEmpty) return;
              FocusScope.of(context).unfocus();
              final ok = await widget.tc.saveSealCode(code);
              if (ok) Get.snackbar('Sello', 'Sello guardado.');
            },
            style: _miniBtn(),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

class _ChecklistBox extends StatelessWidget {
  final TripController tc;
  final TripEvidenceState state;
  const _ChecklistBox({required this.tc, required this.state});

  @override
  Widget build(BuildContext context) {
    final answered = state.questions.where((q) => q.answer != null).length;
    return _ExtraBox(
      title: state.isStart ? '✅ Checklist de salida' : '✅ Checklist de llegada',
      subtitle: state.isStart
          ? 'Responde todas las preguntas antes de iniciar el viaje. '
              '($answered de ${state.questions.length})'
          : 'Responde todas las preguntas antes de finalizar el viaje. '
              '($answered de ${state.questions.length})',
      child: Column(
        children: [
          for (final q in state.questions)
            _ChecklistQuestionTile(
                key: ValueKey('${q.id}-${q.answer}-${q.detail}'), tc: tc, question: q),
        ],
      ),
    );
  }
}

class _ChecklistQuestionTile extends StatefulWidget {
  final TripController tc;
  final EvidenceChecklistQuestion question;
  const _ChecklistQuestionTile({super.key, required this.tc, required this.question});

  @override
  State<_ChecklistQuestionTile> createState() => _ChecklistQuestionTileState();
}

class _ChecklistQuestionTileState extends State<_ChecklistQuestionTile> {
  late final TextEditingController _detailCtrl =
      TextEditingController(text: widget.question.detail ?? '');
  late final TextEditingController _textCtrl =
      TextEditingController(text: widget.question.isYesNo ? '' : (widget.question.answer ?? ''));
  String? _pending;

  EvidenceChecklistQuestion get q => widget.question;

  bool _needsDetailFor(String answer) =>
      q.askDetailAlways || (answer == 'No' && q.askDetailOnNo);

  @override
  void dispose() {
    _detailCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _answer(String answer) async {
    if (_needsDetailFor(answer)) {
      setState(() => _pending = answer);
      return;
    }
    await widget.tc.saveChecklistAnswer(q.id, answer, null);
  }

  Future<void> _saveWithDetail() async {
    final answer = _pending ?? q.answer;
    if (answer == null) return;
    final detail = _detailCtrl.text.trim();
    if (detail.isEmpty) {
      Get.snackbar('Checklist', q.detailPrompt ?? 'Proporciona más detalle.');
      return;
    }
    await widget.tc.saveChecklistAnswer(q.id, answer, detail);
  }

  @override
  Widget build(BuildContext context) {
    final current = _pending ?? q.answer;
    final showDetail = current != null && _needsDetailFor(current);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Ev.gray100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(q.prompt,
              style: const TextStyle(
                  color: Ev.text, fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          if (q.isYesNo)
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final option in const ['Sí', 'No'])
                  GestureDetector(
                    onTap: () => _answer(option),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: current == option
                            ? (option == 'Sí' ? Ev.green : Ev.red)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: current == option
                                ? (option == 'Sí' ? Ev.green : Ev.red)
                                : Ev.gray300,
                            width: 1.5),
                      ),
                      child: Text(option,
                          style: TextStyle(
                              color: current == option
                                  ? Colors.white
                                  : Ev.text,
                              fontSize: 13,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
                if (q.answer != null && _pending == null)
                  const Text('✓ Guardado',
                      style: TextStyle(
                          color: Ev.green,
                          fontSize: 11,
                          fontWeight: FontWeight.w800)),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    decoration: _fieldDecoration('Respuesta'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    final text = _textCtrl.text.trim();
                    if (text.isEmpty) return;
                    widget.tc.saveChecklistAnswer(q.id, text, null);
                  },
                  style: _miniBtn(),
                  child: const Text('Guardar'),
                ),
              ],
            ),
          if (showDetail) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _detailCtrl,
                    decoration:
                        _fieldDecoration(q.detailPrompt ?? 'Proporciona más detalle'),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saveWithDetail,
                  style: _miniBtn(),
                  child: const Text('Guardar'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
