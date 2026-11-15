/// A payment from the shop owner to one of the shop's barbers:
/// `barbershops/{shopId}/payouts/{payoutId}`.
///
/// Created by the shop owner only and never updated. The owner may delete a
/// payout within [kPayoutDeleteWindow] of [createdAt] (to fix mistakes).
/// Barbers read their own payouts (`barberId` == their profile id).
///
/// Stored fields: `barberId`, `amount` (number, ETB, > 0 and <=
/// [kMaxPayoutAmount]), `periodStart` / `periodEnd` (UTC midnight ISO
/// strings, e.g. `2026-11-01T00:00:00.000Z`, start <= end; the date part is
/// the Addis calendar day), `method` ([PayoutMethod] name), `note?` (1..
/// [kMaxPayoutNoteLength] characters), `createdBy` (owner uid), `createdAt`
/// (ISO-8601 UTC instant).
library;

/// How the barber was paid.
enum PayoutMethod {
  cash,
  telebirr,
  bank,
  other;

  static PayoutMethod fromName(Object? name) =>
      PayoutMethod.values.firstWhere((m) => m.name == name, orElse: () => PayoutMethod.other);
}

/// Commission used when a barber profile has no `commissionPercent`.
const int kDefaultCommissionPercent = 50;

/// Largest single payout, in Birr.
const int kMaxPayoutAmount = 1000000;

/// Longest payout note.
const int kMaxPayoutNoteLength = 200;

/// How long after recording a payout the owner may still delete it.
const Duration kPayoutDeleteWindow = Duration(hours: 24);

/// `yyyy-MM-ddT00:00:00.000Z` for the calendar date of [date] (its year,
/// month and day fields; the time is dropped).
String payoutDateIso(DateTime date) => DateTime.utc(date.year, date.month, date.day).toIso8601String();

class Payout {
  const Payout({
    required this.id,
    required this.shopId,
    required this.barberId,
    required this.amount,
    required this.periodStart,
    required this.periodEnd,
    required this.method,
    this.note,
    required this.createdBy,
    required this.createdAt,
  });

  final String id;

  /// Path parent (not stored as a field).
  final String shopId;
  final String barberId;

  /// Birr.
  final double amount;

  /// Calendar dates (UTC midnight; the fields are the Addis date).
  final DateTime periodStart;
  final DateTime periodEnd;

  final PayoutMethod method;
  final String? note;

  /// uid of the owner who recorded it.
  final String createdBy;
  final DateTime createdAt;

  /// Whole amounts are stored as ints.
  static num storedAmount(double amount) => amount == amount.roundToDouble() ? amount.round() : amount;

  Map<String, dynamic> toMap() => {
        'barberId': barberId,
        'amount': storedAmount(amount),
        'periodStart': payoutDateIso(periodStart),
        'periodEnd': payoutDateIso(periodEnd),
        'method': method.name,
        if (note != null && note!.isNotEmpty) 'note': note,
        'createdBy': createdBy,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  factory Payout.fromMap(Map<String, dynamic> map, String id, {required String shopId}) {
    DateTime parse(Object? raw) {
      final parsed = raw is String ? DateTime.tryParse(raw) : null;
      if (parsed != null) return parsed.toUtc();
      // Firestore Timestamps (anything with toDate()).
      try {
        final date = (raw as dynamic)?.toDate();
        if (date is DateTime) return date.toUtc();
      } catch (_) {}
      return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }

    DateTime day(Object? raw) {
      final d = parse(raw);
      return DateTime.utc(d.year, d.month, d.day);
    }

    final note = map['note'];
    return Payout(
      id: id,
      shopId: shopId,
      barberId: map['barberId'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      periodStart: day(map['periodStart']),
      periodEnd: day(map['periodEnd']),
      method: PayoutMethod.fromName(map['method']),
      note: note is String && note.isNotEmpty ? note : null,
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: parse(map['createdAt']),
    );
  }

  /// Newest recorded first.
  static int newestFirst(Payout a, Payout b) {
    final c = b.createdAt.compareTo(a.createdAt);
    return c != 0 ? c : b.id.compareTo(a.id);
  }

  @override
  bool operator ==(Object other) =>
      other is Payout &&
      other.id == id &&
      other.shopId == shopId &&
      other.barberId == barberId &&
      other.amount == amount &&
      other.periodStart == periodStart &&
      other.periodEnd == periodEnd &&
      other.method == method &&
      other.note == note &&
      other.createdBy == createdBy &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, shopId, barberId, amount, periodStart, periodEnd, method, note, createdBy, createdAt);
}
