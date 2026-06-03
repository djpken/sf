enum MeasurementType {
  weight('重量', 'kg'),
  quantity('數量', '個'),
  volume('體積', 'L');

  final String label;
  final String unit;

  const MeasurementType(this.label, this.unit);
}

class InventoryItem {
  final String id;
  String name;
  MeasurementType measurementType;
  double value;
  String? note;

  InventoryItem({
    required this.id,
    required this.name,
    required this.measurementType,
    required this.value,
    this.note,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'measurementType': measurementType.name,
        'value': value,
        'note': note,
      };

  factory InventoryItem.fromJson(Map<String, dynamic> json) => InventoryItem(
        id: json['id'],
        name: json['name'],
        measurementType: MeasurementType.values.byName(json['measurementType']),
        value: (json['value'] as num).toDouble(),
        note: json['note'],
      );
}
