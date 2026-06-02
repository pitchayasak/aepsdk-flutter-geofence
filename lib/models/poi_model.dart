class PoiModel {
  final String identifier;
  final String name;
  final double latitude;
  final double longitude;
  final int radius;
  final String? category;
  final Map<String, String> metadata;

  const PoiModel({
    required this.identifier,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.radius,
    this.category,
    this.metadata = const {},
  });

  factory PoiModel.fromAcpPoi(Map<dynamic, dynamic> raw) {
    final meta = <String, String>{};
    final rawMeta = raw['metadata'];
    if (rawMeta is Map) {
      rawMeta.forEach((k, v) => meta[k.toString()] = v.toString());
    }
    return PoiModel(
      identifier: raw['identifier']?.toString() ?? '',
      name: raw['name']?.toString() ?? 'Unknown POI',
      latitude: (raw['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (raw['longitude'] as num?)?.toDouble() ?? 0.0,
      radius: (raw['radius'] as num?)?.toInt() ?? 100,
      category: raw['category']?.toString(),
      metadata: meta,
    );
  }
}
