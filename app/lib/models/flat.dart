class Flat {
  final String id;
  final String pgId;
  final String name; // e.g. "A-101"
  final String flatType; // e.g. "1BHK", "Studio" — a label only

  Flat({required this.id, required this.pgId, required this.name, required this.flatType});

  factory Flat.fromMap(String id, Map<String, dynamic> map) {
    return Flat(
      id: id,
      pgId: map['pgId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      flatType: map['flatType'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'pgId': pgId,
        'name': name,
        'flatType': flatType,
      };
}
