enum PenaltyType { flat, percentage }

PenaltyType penaltyTypeFromString(String value) =>
    PenaltyType.values.firstWhere((p) => p.name == value, orElse: () => PenaltyType.flat);

class PgSettings {
  final String pgId;
  final int dueDate;
  final PenaltyType penaltyType;
  final double penaltyValue;
  final int reminderDaysBefore;

  PgSettings({
    required this.pgId,
    this.dueDate = 5,
    this.penaltyType = PenaltyType.flat,
    this.penaltyValue = 0,
    this.reminderDaysBefore = 3,
  });

  factory PgSettings.fromMap(String pgId, Map<String, dynamic> map) {
    return PgSettings(
      pgId: pgId,
      dueDate: (map['dueDate'] as num?)?.toInt() ?? 5,
      penaltyType: penaltyTypeFromString(map['penaltyType'] as String? ?? 'flat'),
      penaltyValue: (map['penaltyValue'] as num?)?.toDouble() ?? 0,
      reminderDaysBefore: (map['reminderDaysBefore'] as num?)?.toInt() ?? 3,
    );
  }

  Map<String, dynamic> toMap() => {
        'dueDate': dueDate,
        'penaltyType': penaltyType.name,
        'penaltyValue': penaltyValue,
        'reminderDaysBefore': reminderDaysBefore,
      };
}
