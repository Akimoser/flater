class Animal {
  const Animal({
    required this.name,
    required this.taxonomy,
    required this.locations,
    required this.characteristics,
    this.isDemo = false,
  });
  final bool isDemo;
  final String name;
  final Map<String, String> taxonomy;
  final List<String> locations;
  final Map<String, String> characteristics;
  String get id => '$isDemo|${taxonomy['scientific_name'] ?? ''}|$name';
  String get scientificName => taxonomy['scientific_name'] ?? 'Не указано';
  factory Animal.fromJson(Map<String, dynamic> json) {
    Map<String, String> strings(Object? value) => value is Map
        ? value.map(
            (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
          )
        : {};
    if (json['name'] is! String || (json['name'] as String).trim().isEmpty) {
      throw const FormatException('Animal name is missing');
    }
    return Animal(
      name: json['name'] as String,
      taxonomy: strings(json['taxonomy']),
      locations: json['locations'] is List
          ? (json['locations'] as List).map((e) => e.toString()).toList()
          : [],
      characteristics: strings(json['characteristics']),
      isDemo: json['_demo'] == true,
    );
  }
  Map<String, dynamic> toJson() => {
    'name': name,
    'taxonomy': taxonomy,
    'locations': locations,
    'characteristics': characteristics,
    '_demo': isDemo,
  };
}
