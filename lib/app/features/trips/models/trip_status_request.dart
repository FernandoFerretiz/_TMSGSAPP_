import 'checklist_answer.dart';

class TripStatusRequest {
  final String status;
  final double latitude;
  final double longitude;
  final String? notes;
  // File paths from image_picker; TripService converts them to MultipartFile.
  final List<String> evidenceFilePaths;
  // Sent as its own field (not mixed into evidenceFilePaths) so the backend
  // can flag which TripDocument is the seal photo — see SealCaptureScreen.
  final String? sealPhotoPath;
  // The seal number/code itself (as opposed to sealPhotoPath, the photo of
  // it) — the backend writes this straight into trips.seal.
  final String? sealCode;
  // Pre-trip checklist answers, each with its own linked photos (if any).
  final List<ChecklistAnswer> checklistAnswers;
  // Evidence photos for the trip's additional (sujeción) materials, if any.
  final List<AdditionalMaterialEvidence> additionalMaterialsEvidence;

  const TripStatusRequest({
    required this.status,
    required this.latitude,
    required this.longitude,
    this.notes,
    this.evidenceFilePaths = const [],
    this.sealPhotoPath,
    this.sealCode,
    this.checklistAnswers = const [],
    this.additionalMaterialsEvidence = const [],
  });
}
