class Pg {
  final String id;
  final String name;
  final String address;
  final int totalRooms;
  final List<String> staffIds;
  final String? paymentQrUrl;

  Pg({
    required this.id,
    required this.name,
    required this.address,
    required this.totalRooms,
    required this.staffIds,
    this.paymentQrUrl,
  });

  factory Pg.fromMap(String id, Map<String, dynamic> map) {
    return Pg(
      id: id,
      name: map['name'] as String? ?? '',
      address: map['address'] as String? ?? '',
      totalRooms: (map['totalRooms'] as num?)?.toInt() ?? 0,
      staffIds: List<String>.from(map['staffIds'] as List? ?? const []),
      paymentQrUrl: map['paymentQrUrl'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'address': address,
        'totalRooms': totalRooms,
        'staffIds': staffIds,
        if (paymentQrUrl != null) 'paymentQrUrl': paymentQrUrl,
      };
}
