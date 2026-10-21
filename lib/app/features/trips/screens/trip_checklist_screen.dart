import '../../../core/design/sx_design.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/config/app_config.dart';
import '../controllers/trip_controller.dart';
import '../models/checklist_answer.dart';
import '../models/checklist_question.dart';
import '../widgets/photo_source_sheet.dart';

enum _Stage { question, detail, photo }

/// Chatbot-style pre-trip checklist. Walks the operator through
/// [_questions] one at a time, asking for a yes/no or free-text
/// answer and, when required, a supporting photo.
class TripChecklistScreen extends StatefulWidget {
  const TripChecklistScreen({super.key});

  @override
  State<TripChecklistScreen> createState() => _TripChecklistScreenState();
}

class _TripChecklistScreenState extends State<TripChecklistScreen> {
  late final TripController _tc;
  List<ChecklistQuestion> get _questions => _tc.checklistQuestions;
  final _scrollCtrl = ScrollController();
  final _textCtrl = TextEditingController();

  late int _currentIndex;
  _Stage _stage = _Stage.question;
  String? _draftAnswer;
  String? _draftDetail;
  final List<XFile> _pendingPhotos = [];

  @override
  void initState() {
    super.initState();
    _tc = Get.find<TripController>();
    _currentIndex = _tc.checklistAnswers.length;
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  bool get _isDone => _currentIndex >= _questions.length;

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  void _handleYesNo(bool yes) {
    final q = _questions[_currentIndex];
    setState(() => _draftAnswer = yes ? 'Sí' : 'No');
    _scrollToEnd();

    if (q.askDetailAlways || (!yes && q.askDetailOnNo)) {
      setState(() => _stage = _Stage.detail);
      return;
    }
    final needsPhoto = q.photoAlwaysRequired || (!yes && q.photoRequiredOnNo);
    if (needsPhoto) {
      setState(() => _stage = _Stage.photo);
    } else {
      _finalizeAnswer();
    }
  }

  void _submitText() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    final q = _questions[_currentIndex];
    _textCtrl.clear();

    if (_stage == _Stage.detail) {
      setState(() => _draftDetail = text);
      setState(() => _stage = _Stage.photo); // detail is only asked when a photo is also required
    } else {
      setState(() => _draftAnswer = text);
      if (q.photoAlwaysRequired) {
        setState(() => _stage = _Stage.photo);
      } else {
        _finalizeAnswer();
      }
    }
    _scrollToEnd();
  }

  Future<void> _attachPhotos() async {
    final picked = await showPhotoSourceSheet(context);
    if (picked.isEmpty) return;
    setState(() => _pendingPhotos.addAll(picked));
    _scrollToEnd();
  }

  void _finalizeAnswer() {
    final q = _questions[_currentIndex];
    _tc.checklistAnswers.add(ChecklistAnswer(
      questionId: q.id,
      prompt: q.prompt,
      answer: _draftAnswer ?? '',
      detail: _draftDetail,
      photos: List.of(_pendingPhotos),
    ));
    setState(() {
      _currentIndex++;
      _stage = _Stage.question;
      _draftAnswer = null;
      _draftDetail = null;
      _pendingPhotos.clear();
    });
    _scrollToEnd();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FF),
      appBar: SxAppBar(title: const Text(
          'Checklist',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        )),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(16),
                children: _buildTranscript(),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Color(0x14000000), blurRadius: 8),
                ],
              ),
              child: SafeArea(top: false, child: _buildInputBar()),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildTranscript() {
    final children = <Widget>[];
    for (var i = 0; i < _currentIndex; i++) {
      children.addAll(_answeredBubbles(i));
    }
    if (!_isDone) {
      children.addAll(_activeBubbles());
    } else {
      children.add(const _BotBubble(
          '¡Checklist completado! Gracias por revisar la unidad.'));
    }
    return children;
  }

  List<Widget> _answeredBubbles(int i) {
    final q = _questions[i];
    final a = _tc.checklistAnswers[i];
    final list = <Widget>[
      _BotBubble(q.prompt),
      _UserBubble(a.answer),
    ];
    if (a.detail != null && a.detail!.isNotEmpty) {
      list.add(_BotBubble(q.detailPrompt ?? 'Proporciona más detalle'));
      list.add(_UserBubble(a.detail!));
    }
    if (a.photos.isNotEmpty) {
      list.add(const _BotBubble('Por favor adjunta una fotografía de evidencia.'));
      list.add(_PhotoBubble(a.photos));
    }
    return list;
  }

  List<Widget> _activeBubbles() {
    final q = _questions[_currentIndex];
    final list = <Widget>[_BotBubble(q.prompt)];
    if (_draftAnswer != null) list.add(_UserBubble(_draftAnswer!));
    if (_stage == _Stage.detail || _draftDetail != null) {
      list.add(_BotBubble(q.detailPrompt ?? 'Proporciona más detalle'));
    }
    if (_draftDetail != null) list.add(_UserBubble(_draftDetail!));
    if (_stage == _Stage.photo) {
      list.add(const _BotBubble(
          'Por favor toma o adjunta una fotografía de evidencia.'));
    }
    if (_pendingPhotos.isNotEmpty) list.add(_PhotoBubble(_pendingPhotos));
    return list;
  }

  Widget _buildInputBar() {
    if (_isDone) {
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: () => Get.back(),
          icon: const Icon(Icons.check_circle_rounded),
          label: const Text('Volver'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.royalBlue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    }

    final q = _questions[_currentIndex];

    if (_stage == _Stage.question && q.type == ChecklistQuestionType.yesNo) {
      return Row(
        children: [
          Expanded(
            child: _QuickReplyButton(
              label: 'Sí',
              onTap: () => _handleYesNo(true),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _QuickReplyButton(
              label: 'No',
              onTap: () => _handleYesNo(false),
            ),
          ),
        ],
      );
    }

    if (_stage == _Stage.photo) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _attachPhotos,
                  icon: const Icon(Icons.camera_alt_rounded, size: 18),
                  label: const Text('Adjuntar foto'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.royalBlue,
                    side: const BorderSide(color: AppColors.royalBlue),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _pendingPhotos.isEmpty ? null : _finalizeAnswer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.royalBlue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppColors.fieldBorder,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Continuar'),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Free-text question or detail follow-up.
    final hint = _stage == _Stage.detail
        ? (q.detailPrompt ?? 'Escribe aquí...')
        : 'Escribe tu respuesta...';
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _textCtrl,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _submitText(),
            decoration: InputDecoration(
              hintText: hint,
              filled: true,
              fillColor: AppColors.fieldFill,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.fieldBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.fieldBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.royalBlue, width: 2),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: AppColors.royalBlue,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: _submitText,
            child: const Padding(
              padding: EdgeInsets.all(13),
              child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Chat bubbles ──────────────────────────────────────────────────────────

class _BotBubble extends StatelessWidget {
  final String text;
  const _BotBubble(this.text);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(14),
            bottomLeft: Radius.circular(14),
            bottomRight: Radius.circular(14),
          ),
          boxShadow: [
            BoxShadow(
                color: AppColors.navyBlue.withValues(alpha: 0.06),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Text(text,
            style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.3)),
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  final String text;
  const _UserBubble(this.text);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: const BoxDecoration(
          gradient: AppColors.buttonGradient,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(4),
            bottomLeft: Radius.circular(14),
            bottomRight: Radius.circular(14),
          ),
        ),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _PhotoBubble extends StatelessWidget {
  final List<XFile> photos;
  const _PhotoBubble(this.photos);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: photos
              .map((f) => Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        File(f.path),
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        cacheWidth: 128,
                        errorBuilder: (_, __, ___) => Container(
                          width: 64,
                          height: 64,
                          color: AppColors.fieldFill,
                          child: const Icon(Icons.image_outlined,
                              color: AppColors.textLight),
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _QuickReplyButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickReplyButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.royalBlue,
        side: const BorderSide(color: AppColors.royalBlue),
        padding: const EdgeInsets.symmetric(vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
    );
  }
}
