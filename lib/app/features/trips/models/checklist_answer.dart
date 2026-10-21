import 'package:image_picker/image_picker.dart';

/// The recorded answer for a single [ChecklistQuestion].
class ChecklistAnswer {
  final String questionId;
  final String prompt;
  final String answer;
  final String? detail;
  final List<XFile> photos;

  const ChecklistAnswer({
    required this.questionId,
    required this.prompt,
    required this.answer,
    this.detail,
    this.photos = const [],
  });
}

/// Evidencia capturada para un material de sujeción agregado al viaje —
/// ver [AdditionalMaterialItem] / TripAdditionalMaterial en el backend.
class AdditionalMaterialEvidence {
  final int tripAdditionalMaterialId;
  final List<XFile> photos;

  const AdditionalMaterialEvidence({
    required this.tripAdditionalMaterialId,
    this.photos = const [],
  });
}
