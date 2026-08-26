class Pg {
  final String id;
  final String name;
  final String? paymentQrUrl;

  Pg({required this.id, required this.name, this.paymentQrUrl});

  factory Pg.fromMap(String id, Map<String, dynamic> map) {
    return Pg(
      id: id,
      name: map['name'] as String? ?? '',
      paymentQrUrl: map['paymentQrUrl'] as String?,
    );
  }
}
