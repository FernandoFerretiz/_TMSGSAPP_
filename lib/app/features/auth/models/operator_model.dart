class OperatorModel {
  final int id;
  final String name;

  const OperatorModel({
    required this.id,
    required this.name,
  });

  factory OperatorModel.fromJson(Map<String, dynamic> json) => OperatorModel(
        id: json['id'] as int,
        name: json['name'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
}
