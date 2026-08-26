class RoomType {
  final String id;
  final String pgId;
  final String name;
  final double defaultRent;
  final int capacity;

  RoomType({
    required this.id,
    required this.pgId,
    required this.name,
    required this.defaultRent,
    required this.capacity,
  });

  factory RoomType.fromMap(String id, Map<String, dynamic> map) {
    return RoomType(
      id: id,
      pgId: map['pgId'] as String? ?? '',
      name: map['name'] as String? ?? '',
      defaultRent: (map['defaultRent'] as num?)?.toDouble() ?? 0,
      capacity: (map['capacity'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toMap() => {
        'pgId': pgId,
        'name': name,
        'defaultRent': defaultRent,
        'capacity': capacity,
      };
}
