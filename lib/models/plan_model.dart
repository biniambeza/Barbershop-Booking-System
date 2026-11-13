/// A subscription plan at `plans/{planId}` ('trial' | 'basic' | 'pro').
/// Public read, admin write.
class SubscriptionPlan {
  final String id;
  final String name;
  final double priceMonthlyEtb;

  /// Maximum number of barbers; a negative value (-1) means unlimited.
  final int maxBarbers;
  final List<String> features;
  final bool active;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.priceMonthlyEtb,
    required this.maxBarbers,
    this.features = const [],
    this.active = true,
  });

  /// Plan ids the payments backend accepts for a paid subscription.
  static const List<String> purchasableIds = ['basic', 'pro'];

  /// Every value of barbershops.subscriptionPlan.
  static const List<String> knownIds = ['trial', 'basic', 'pro'];

  bool get isUnlimited => maxBarbers < 0;

  /// Whether a shop with [barberCount] barbers fits in this plan.
  bool allowsBarbers(int barberCount) => isUnlimited || barberCount <= maxBarbers;

  /// Can be bought with createSubscriptionPayment.
  bool get isPurchasable => active && priceMonthlyEtb > 0 && purchasableIds.contains(id);

  String get barberLimitLabel => isUnlimited ? 'Unlimited barbers' : 'Up to $maxBarbers barber${maxBarbers == 1 ? '' : 's'}';

  SubscriptionPlan copyWith({
    String? name,
    double? priceMonthlyEtb,
    int? maxBarbers,
    List<String>? features,
    bool? active,
  }) {
    return SubscriptionPlan(
      id: id,
      name: name ?? this.name,
      priceMonthlyEtb: priceMonthlyEtb ?? this.priceMonthlyEtb,
      maxBarbers: maxBarbers ?? this.maxBarbers,
      features: features ?? this.features,
      active: active ?? this.active,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'priceMonthlyEtb': priceMonthlyEtb,
      'maxBarbers': maxBarbers,
      'features': features,
      'active': active,
    };
  }

  factory SubscriptionPlan.fromMap(Map<String, dynamic> map, String id) {
    return SubscriptionPlan(
      id: id,
      name: map['name'] ?? id,
      priceMonthlyEtb: (map['priceMonthlyEtb'] as num?)?.toDouble() ?? 0,
      maxBarbers: (map['maxBarbers'] as num?)?.toInt() ?? 1,
      features: (map['features'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      active: map['active'] ?? true,
    );
  }
}
