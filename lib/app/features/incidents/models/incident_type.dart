class IncidentExtraField {
  final String key;
  final String label;
  final String type;
  final bool required;

  const IncidentExtraField({
    required this.key,
    required this.label,
    required this.type,
    required this.required,
  });

  factory IncidentExtraField.fromJson(Map<String, dynamic> json) =>
      IncidentExtraField(
        key: json['key']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        type: json['type']?.toString() ?? 'text',
        required: json['required'] == true,
      );
}

class IncidentType {
  final int id;
  final String name;
  final String? description;
  final bool requiresPhoto;
  final bool requiresCanContinueTrip;
  final List<IncidentExtraField> extraFields;

  const IncidentType({
    required this.id,
    required this.name,
    this.description,
    required this.requiresPhoto,
    required this.requiresCanContinueTrip,
    required this.extraFields,
  });

  factory IncidentType.fromJson(Map<String, dynamic> json) => IncidentType(
        id: json['id'] as int,
        name: json['name']?.toString() ?? '',
        description: json['description']?.toString(),
        requiresPhoto: json['requires_photo'] == true,
        requiresCanContinueTrip: json['requires_can_continue_trip'] == true,
        extraFields: (json['extra_fields'] as List? ?? [])
            .map((e) => IncidentExtraField.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class IncidentCategory {
  final int id;
  final String name;
  final List<IncidentType> types;

  const IncidentCategory({
    required this.id,
    required this.name,
    required this.types,
  });

  factory IncidentCategory.fromJson(Map<String, dynamic> json) =>
      IncidentCategory(
        id: json['id'] as int,
        name: json['name']?.toString() ?? '',
        types: (json['types'] as List? ?? [])
            .map((e) => IncidentType.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
