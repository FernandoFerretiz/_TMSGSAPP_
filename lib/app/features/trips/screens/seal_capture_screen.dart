import '../../../core/design/sx_design.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/config/app_config.dart';
import '../controllers/trip_controller.dart';
import '../widgets/photo_source_sheet.dart';

enum _Stage { code, photo, done }

/// Chatbot-style capture for the security seal: first asks for the seal's
/// code, then requests exactly one photo of it — same conversational
/// pattern as [TripChecklistScreen], scoped to this single question.
class SealCaptureScreen extends StatefulWidget {
  const SealCaptureScreen({super.key});

  @override
  State<SealCaptureScreen> createState() => _SealCaptureScreenState();
}

class _SealCaptureScreenState extends State<SealCaptureScreen> {
  late final TripController _tc;
  final _scrollCtrl = ScrollController();
  final _textCtrl = TextEditingController();

  late _Stage _stage;
  String? _draftCode;
  XFile? _draftPhoto;

  @override
  void initState() {
    super.initState();
    _tc = Get.find<TripController>();
    final hasCode = _tc.sealCode.value.isNotEmpty;
    final hasPhoto = _tc.sealPhotos.isNotEmpty;
    if (hasCode) _draftCode = _tc.sealCode.value;
    if (hasPhoto) _draftPhoto = _tc.sealPhotos.first;
    _stage = hasCode && hasPhoto
        ? _Stage.done
        : hasCode
            ? _Stage.photo
            : _Stage.code;
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

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

  void _submitCode() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    setState(() {
      _draftCode = text;
      _stage = _Stage.photo;
    });
    _scrollToEnd();
  }

  Future<void> _capturePhoto() async {
    final picked = await showPhotoSourceSheet(context);
    if (picked.isEmpty) return;
    // Only one photo of the seal is needed — a new capture replaces
    // whatever was picked before rather than piling up.
    setState(() => _draftPhoto = picked.first);
    _scrollToEnd();
  }

  void _finish() {
    if (_draftCode == null || _draftPhoto == null) return;
    _tc.sealCode.value = _draftCode!;
    _tc.sealPhotos
      ..clear()
      ..add(_draftPhoto!);
    setState(() => _stage = _Stage.done);
    _scrollToEnd();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FF),
      appBar: SxAppBar(title: const Text(
          'Foto del sello',
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
    final children = <Widget>[
      const _BotBubble(
          '¿Cuál es el código del sello de seguridad colocado en la unidad?'),
    ];
    if (_draftCode != null) children.add(_UserBubble(_draftCode!));
    if (_stage == _Stage.photo || _draftPhoto != null) {
      children.add(const _BotBubble(
          'Ahora toma una foto del sello, con el número visible.'));
    }
    if (_draftPhoto != null) children.add(_PhotoBubble(_draftPhoto!));
    if (_stage == _Stage.done) {
      children.add(const _BotBubble('¡Listo! Sello registrado.'));
    }
    return children;
  }

  Widget _buildInputBar() {
    if (_stage == _Stage.done) {
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    }

    if (_stage == _Stage.photo) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _capturePhoto,
              icon: const Icon(Icons.camera_alt_rounded, size: 18),
              label: Text(_draftPhoto == null ? 'Tomar foto' : 'Repetir foto'),
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
              onPressed: _draftPhoto == null ? null : _finish,
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
      );
    }

    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _textCtrl,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _submitCode(),
            decoration: InputDecoration(
              hintText: 'Código del sello...',
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
            onTap: _submitCode,
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

// ── Chat bubbles (same look as TripChecklistScreen) ─────────────────────────

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
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
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
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
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
  final XFile photo;
  const _PhotoBubble(this.photo);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(
            File(photo.path),
            width: 64,
            height: 64,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 64,
              height: 64,
              color: AppColors.fieldFill,
              child: const Icon(Icons.image_outlined,
                  color: AppColors.textLight),
            ),
          ),
        ),
      ),
    );
  }
}
