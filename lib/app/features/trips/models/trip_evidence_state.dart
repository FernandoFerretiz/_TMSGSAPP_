/// Archivo de evidencia ya subido al servidor (link de evidencias del viaje).
class EvidenceFile {
  final String uuid;
  final String name;
  final bool isImage;
  final String url;
  final bool canDelete;

  const EvidenceFile({
    required this.uuid,
    required this.name,
    required this.isImage,
    required this.url,
    required this.canDelete,
  });

  factory EvidenceFile.fromJson(Map<String, dynamic> json) => EvidenceFile(
        uuid: json['uuid'].toString(),
        name: (json['name'] ?? '').toString(),
        isImage: json['is_image'] == true,
        url: (json['url'] ?? '').toString(),
        canDelete: json['can_delete'] == true,
      );
}

/// Pregunta del checklist de la etapa, con la respuesta ya guardada (si hay).
class EvidenceChecklistQuestion {
  final String id;
  final String prompt;
  final String type;
  final String? detailPrompt;
  final bool askDetailAlways;
  final bool askDetailOnNo;
  final String? answer;
  final String? detail;

  const EvidenceChecklistQuestion({
    required this.id,
    required this.prompt,
    required this.type,
    this.detailPrompt,
    this.askDetailAlways = false,
    this.askDetailOnNo = false,
    this.answer,
    this.detail,
  });

  bool get isYesNo => type == 'yes_no';

  bool get needsDetail =>
      askDetailAlways || (answer == 'No' && askDetailOnNo);

  factory EvidenceChecklistQuestion.fromJson(Map<String, dynamic> json) =>
      EvidenceChecklistQuestion(
        id: json['id'].toString(),
        prompt: (json['prompt'] ?? '').toString(),
        type: (json['type'] ?? '').toString(),
        detailPrompt: json['detail_prompt']?.toString(),
        askDetailAlways: json['ask_detail_always'] == true,
        askDetailOnNo: json['ask_detail_on_no'] == true,
        answer: json['answer']?.toString(),
        detail: json['detail']?.toString(),
      );
}

/// Estado de la carga de evidencias de un viaje, tal como lo reporta
/// GET /api/mobile/trips/{id}/evidence (misma lógica que el link web).
class TripEvidenceState {
  static const startPhotos = 'start_photos';
  static const startDocs = 'start_docs';
  static const sealPhoto = 'seal_photo';
  static const endPhotos = 'end_photos';
  static const endPod = 'end_pod';
  static const endSealPhoto = 'end_seal_photo';

  final String stage; // 'start' | 'finish'
  final Map<String, List<EvidenceFile>> files;
  final bool canUpload;
  final bool canFinish;
  final bool requiresDocuments;
  final bool requiresSeal;
  final bool requiresChecklist;
  final bool podRequired;
  final bool requiresEndEvidence;
  final bool requiresEndPhotos;
  final bool sealActive;
  final String sealKind;
  final String sealCode;
  final List<EvidenceChecklistQuestion> questions;

  /// Primer requisito que falta para continuar; null si ya se puede.
  final String? gap;

  const TripEvidenceState({
    required this.stage,
    required this.files,
    required this.canUpload,
    required this.canFinish,
    required this.requiresDocuments,
    required this.requiresSeal,
    required this.requiresChecklist,
    required this.podRequired,
    required this.requiresEndEvidence,
    required this.requiresEndPhotos,
    required this.sealActive,
    required this.sealKind,
    required this.sealCode,
    required this.questions,
    required this.gap,
  });

  bool get isStart => stage == 'start';

  List<EvidenceFile> filesOf(String kind) => files[kind] ?? const [];

  int count(String kind) => filesOf(kind).length;

  int get startCount => count(startPhotos) + count(startDocs);

  int get endCount => count(endPhotos) + count(endPod);

  bool get ready => gap == null;

  factory TripEvidenceState.fromJson(Map<String, dynamic> json) {
    final rawFiles = (json['files'] as Map?) ?? const {};
    final extras = (json['extras'] as Map?) ?? const {};
    final requires = (json['requires'] as Map?) ?? const {};

    return TripEvidenceState(
      stage: (json['stage'] ?? 'start').toString(),
      files: {
        for (final entry in rawFiles.entries)
          entry.key.toString(): (entry.value as List)
              .map((e) => EvidenceFile.fromJson(e as Map<String, dynamic>))
              .toList(),
      },
      canUpload: json['can_upload'] == true,
      canFinish: json['can_finish'] == true,
      requiresDocuments: requires['documents'] == true,
      requiresSeal: requires['seal'] == true,
      requiresChecklist: requires['checklist'] == true,
      podRequired: json['pod_required'] == true,
      requiresEndEvidence: json['requires_end_evidence'] == true,
      requiresEndPhotos: json['requires_end_photos'] == true,
      sealActive: extras['seal'] == true,
      sealKind: (extras['seal_kind'] ?? 'seal_photo').toString(),
      sealCode: (extras['seal_code'] ?? '').toString(),
      questions: ((extras['questions'] as List?) ?? const [])
          .map((e) =>
              EvidenceChecklistQuestion.fromJson(e as Map<String, dynamic>))
          .toList(),
      gap: json['gap']?.toString(),
    );
  }
}
