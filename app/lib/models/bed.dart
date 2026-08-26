class Bed {
  final String id;
  final String pgId;
  final String flatId;
  final String roomId;
  final String bedLabel; // e.g. "Bed 1"
  final String? tenantId;

  Bed({
    required this.id,
    required this.pgId,
    required this.flatId,
    required this.roomId,
    required this.bedLabel,
    this.tenantId,
  });

  bool get isOccupied => tenantId != null && tenantId!.isNotEmpty;

  factory Bed.fromMap(String id, Map<String, dynamic> map) {
    return Bed(
      id: id,
      pgId: map['pgId'] as String? ?? '',
      flatId: map['flatId'] as String? ?? '',
      roomId: map['roomId'] as String? ?? '',
      bedLabel: map['bedLabel'] as String? ?? '',
      tenantId: map['tenantId'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'pgId': pgId,
        'flatId': flatId,
        'roomId': roomId,
        'bedLabel': bedLabel,
        'tenantId': tenantId,
      };
}
