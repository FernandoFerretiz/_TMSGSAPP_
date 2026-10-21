enum ChecklistQuestionType { yesNo, text }

/// A single checklist question shown by the pre-trip chatbot.
///
/// Comes from the backend (`trip.checklist_questions` in the active-trip
/// response) so it can vary per trip, e.g. an empty trip skips the seal
/// question. See `App\Models\TripChecklistQuestion` in the API.
class ChecklistQuestion {
  final String id;
  final String prompt;
  final ChecklistQuestionType type;

  /// Photo is required whenever the answer is "No" (only applies to [ChecklistQuestionType.yesNo]).
  final bool photoRequiredOnNo;

  /// Photo is always required, regardless of the answer (e.g. free-text questions).
  final bool photoAlwaysRequired;

  /// When answering "No", ask for an extra free-text detail before the photo step.
  final bool askDetailOnNo;

  /// Ask for the detail regardless of the answer (mirrors [photoAlwaysRequired]).
  final bool askDetailAlways;
  final String? detailPrompt;

  const ChecklistQuestion({
    required this.id,
    required this.prompt,
    this.type = ChecklistQuestionType.yesNo,
    this.photoRequiredOnNo = false,
    this.photoAlwaysRequired = false,
    this.askDetailOnNo = false,
    this.askDetailAlways = false,
    this.detailPrompt,
  });

  factory ChecklistQuestion.fromJson(Map<String, dynamic> json) =>
      ChecklistQuestion(
        id: (json['id'] ?? '').toString(),
        prompt: (json['prompt'] ?? '').toString(),
        type: json['type'] == 'text'
            ? ChecklistQuestionType.text
            : ChecklistQuestionType.yesNo,
        photoRequiredOnNo: json['photo_required_on_no'] == true,
        photoAlwaysRequired: json['photo_always_required'] == true,
        askDetailOnNo: json['ask_detail_on_no'] == true,
        askDetailAlways: json['ask_detail_always'] == true,
        detailPrompt: json['detail_prompt']?.toString(),
      );
}
