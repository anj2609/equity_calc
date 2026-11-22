/// Rows of the results comparison table, in the spreadsheet's order.
enum ResultRow {
  grossPurchase('Gross purchase value'),
  buyCharges('Buy brokerage & charges (excl. STT)', defaultVisible: false),
  buyStt('Buy-side STT', defaultVisible: false),
  totalInvestment('Total cash investment incl. all buy charges', bold: true),
  grossSale('Gross sale value'),
  sellBrokerage('Brokerage on sale', defaultVisible: false),
  otherSellCharges('Other selling charges', defaultVisible: false),
  sellStt('Sell-side STT', defaultVisible: false),
  exitLoad('Exit load'),
  totalSellingCosts('Total selling costs incl. exit load & STT'),
  netSaleProceeds('Net sale proceeds before tax', bold: true),
  taxableGain(
    'Taxable capital gain / (loss) (excl. STT)',
    bold: true,
    shaded: true,
  ),
  taxType('Tax type & rate'),
  tax('Estimated capital gains tax'),
  netAfterTax('Net amount received after tax'),
  netProfit(
    'Net profit / (loss) after tax & all charges',
    bold: true,
    shaded: true,
  ),
  netReturn('Net return for holding period'),
  holdingDays('Holding period (days)'),
  simpleAnnualised('Simple annualised net return', bold: true),
  cagr('Compounded annualised net return / CAGR', bold: true),
  targetSimple(
    'Sell price for target return – simple basis (per share)',
    bold: true,
    shaded: true,
  ),
  targetCagr(
    'Sell price for target return – CAGR basis (per share)',
    bold: true,
    shaded: true,
  ),
  targetBuySimple(
    'Buy price for target return – simple basis (per share)',
    bold: true,
    shaded: true,
  ),
  targetBuyCagr(
    'Buy price for target return – CAGR basis (per share)',
    bold: true,
    shaded: true,
  ),
  dipBuyPrice(
    'Buy-on-dip price (buy target % below purchase price)',
    bold: true,
  ),
  maxBuyPrice(
    'Highest buy price that still earns the buy target % net',
    bold: true,
  );

  const ResultRow(
    this.label, {
    this.bold = false,
    this.shaded = false,
    this.defaultVisible = true,
  });

  final String label;
  final bool bold;
  final bool shaded;
  final bool defaultVisible;

  static Set<ResultRow> get defaultHidden => {
    for (final r in values)
      if (!r.defaultVisible) r,
  };
}
