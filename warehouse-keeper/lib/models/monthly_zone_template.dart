class MonthlyZoneTemplate {
  final String id;
  String name;
  bool isActive;
  final DateTime createdAt;
  DateTime updatedAt;

  MonthlyZoneTemplate({
    required this.id,
    required this.name,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory MonthlyZoneTemplate.fromJson(Map<String, dynamic> json) {
    return MonthlyZoneTemplate(
      id: json['id'],
      name: json['name'],
      isActive: json['isActive'] ?? true,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }
}
