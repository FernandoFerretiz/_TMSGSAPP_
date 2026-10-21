/// What the backend expects the operator to submit for this trip's current
/// stage (start or finish) — driven by `App\Services\TripRequirementResolverService`
/// on the backend, based on empty/loaded and circuit position (outbound/return).
/// The checklist question catalog itself is untouched; this only decides
/// whether that screen is required and whether the seal question applies.
class TripRequirements {
  final bool requiresChecklist;
  final bool requiresDocuments;
  final bool requiresSeal;

  const TripRequirements({
    this.requiresChecklist = true,
    this.requiresDocuments = true,
    this.requiresSeal = true,
  });

  factory TripRequirements.fromJson(Map<String, dynamic>? json) =>
      TripRequirements(
        requiresChecklist: json?['requires_checklist'] != false,
        requiresDocuments: json?['requires_documents'] != false,
        requiresSeal: json?['requires_seal'] != false,
      );
}
