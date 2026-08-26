class Room {
  final String id;
  final String pgId;
  final String flatId;
  final String roomTypeId;
  final String roomNumber; // e.g. "Room 1"
  final int capacity; // snapshot of roomType.capacity at creation time

  Room({
    required this.id,
    required this.pgId,
    required this.flatId,
    required this.roomTypeId,
    required this.roomNumber,
    required this.capacity,
  });

  factory Room.fromMap(String id, Map<String, dynamic> map) {
    return Room(
      id: id,
      pgId: map['pgId'] as String? ?? '',
      flatId: map['flatId'] as String? ?? '',
      roomTypeId: map['roomTypeId'] as String? ?? '',
      roomNumber: map['roomNumber'] as String? ?? '',
      capacity: (map['capacity'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'pgId': pgId,
        'flatId': flatId,
        'roomTypeId': roomTypeId,
        'roomNumber': roomNumber,
        'capacity': capacity,
      };
}
