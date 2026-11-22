/// Statutory charge rates for equity delivery trades, used when a
/// calculation has auto charges switched on. All values are editable estimates.
class ChargeRates {
  const ChargeRates({
    this.sttBuyPct = 0.1,
    this.sttSellPct = 0.1,
    this.stampDutyBuyPct = 0.015,
    this.exchangeTxnPct = 0.00297,
    this.sebiFeePerCrore = 10,
    this.dpChargePerSell = 13.5,
    this.gstPct = 18,
  });

  final double sttBuyPct;
  final double sttSellPct;
  final double stampDutyBuyPct;
  final double exchangeTxnPct;
  final double sebiFeePerCrore;
  final double dpChargePerSell;
  final double gstPct;

  ChargeRates copyWith({
    double? sttBuyPct,
    double? sttSellPct,
    double? stampDutyBuyPct,
    double? exchangeTxnPct,
    double? sebiFeePerCrore,
    double? dpChargePerSell,
    double? gstPct,
  }) => ChargeRates(
    sttBuyPct: sttBuyPct ?? this.sttBuyPct,
    sttSellPct: sttSellPct ?? this.sttSellPct,
    stampDutyBuyPct: stampDutyBuyPct ?? this.stampDutyBuyPct,
    exchangeTxnPct: exchangeTxnPct ?? this.exchangeTxnPct,
    sebiFeePerCrore: sebiFeePerCrore ?? this.sebiFeePerCrore,
    dpChargePerSell: dpChargePerSell ?? this.dpChargePerSell,
    gstPct: gstPct ?? this.gstPct,
  );

  Map<String, Object> toJson() => {
    'sttBuyPct': sttBuyPct,
    'sttSellPct': sttSellPct,
    'stampDutyBuyPct': stampDutyBuyPct,
    'exchangeTxnPct': exchangeTxnPct,
    'sebiFeePerCrore': sebiFeePerCrore,
    'dpChargePerSell': dpChargePerSell,
    'gstPct': gstPct,
  };

  factory ChargeRates.fromJson(Map<String, dynamic> j) {
    const d = ChargeRates();
    double n(String k, double fallback) =>
        (j[k] as num?)?.toDouble() ?? fallback;
    return ChargeRates(
      sttBuyPct: n('sttBuyPct', d.sttBuyPct),
      sttSellPct: n('sttSellPct', d.sttSellPct),
      stampDutyBuyPct: n('stampDutyBuyPct', d.stampDutyBuyPct),
      exchangeTxnPct: n('exchangeTxnPct', d.exchangeTxnPct),
      sebiFeePerCrore: n('sebiFeePerCrore', d.sebiFeePerCrore),
      dpChargePerSell: n('dpChargePerSell', d.dpChargePerSell),
      gstPct: n('gstPct', d.gstPct),
    );
  }
}
