class TareContainer {
  final String id;
  final String name;
  final int grams;
  final bool isFavorite;

  const TareContainer({
    required this.id,
    required this.name,
    required this.grams,
    this.isFavorite = false,
  });

  double get kilograms => grams / 1000;
  String get note => '已扣除$name ${grams}g';

  TareContainer copyWith({
    String? id,
    String? name,
    int? grams,
    bool? isFavorite,
  }) {
    return TareContainer(
      id: id ?? this.id,
      name: name ?? this.name,
      grams: grams ?? this.grams,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'grams': grams,
        'isFavorite': isFavorite,
      };

  factory TareContainer.fromJson(Map<String, dynamic> json) {
    return TareContainer(
      id: json['id'],
      name: json['name'],
      grams: json['grams'],
      isFavorite: json['isFavorite'] as bool? ?? false,
    );
  }
}
