enum StaffRole { owner, manager }

StaffRole staffRoleFromString(String value) =>
    StaffRole.values.firstWhere((r) => r.name == value, orElse: () => StaffRole.manager);

class Staff {
  final String id;
  final String name;
  final StaffRole role;
  final List<String> assignedPgIds;
  final List<String> fcmTokens;

  Staff({
    required this.id,
    required this.name,
    required this.role,
    required this.assignedPgIds,
    this.fcmTokens = const [],
  });

  factory Staff.fromMap(String id, Map<String, dynamic> map) {
    return Staff(
      id: id,
      name: map['name'] as String? ?? '',
      role: staffRoleFromString(map['role'] as String? ?? 'manager'),
      assignedPgIds: List<String>.from(map['assignedPgIds'] as List? ?? const []),
      fcmTokens: List<String>.from(map['fcmTokens'] as List? ?? const []),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'role': role.name,
        'assignedPgIds': assignedPgIds,
        'fcmTokens': fcmTokens,
      };
}
