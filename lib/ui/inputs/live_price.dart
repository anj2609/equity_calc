import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/input_field.dart';
import '../../models/trade_inputs.dart';
import '../../services/price_service.dart';
import '../../state/app_state.dart';
import '../../utils/format.dart';
import '../theme.dart';
import 'fields.dart';

/// Symbol field with search, a "Fetch current price" button and buttons to
/// copy the fetched price into the purchase or selling price.
class LivePriceBox extends StatelessWidget {
  const LivePriceBox({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final colors = AppColors.of(context);
    final symbol = state.scopeInputs.symbol.trim();
    final quote = state.quote;
    final error = state.quoteError;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: ScopedField(
                InputField.symbol,
                hint: 'e.g. RELIANCE.NS',
                helper: '.NS for NSE, .BO for BSE. Tap search to look one up.',
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: IconButton.filledTonal(
                icon: const Icon(Icons.search),
                tooltip: 'Find symbol',
                onPressed: () async {
                  final match = await showSymbolSearch(
                    context,
                    initial: state.scopeInputs.shareName,
                  );
                  if (match != null) state.pickSymbol(match);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FilledButton.tonalIcon(
          onPressed: symbol.isEmpty || state.fetchingQuote
              ? null
              : state.fetchQuote,
          icon: state.fetchingQuote
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.cloud_download_outlined),
          label: const Text('Fetch current price'),
        ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(
            error,
            style: theme.textTheme.bodySmall?.copyWith(color: colors.loss),
          ),
        ],
        if (quote != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.6,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  children: [
                    Text(
                      formatMoney(quote.price),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (quote.previousClose case final prev? when prev > 0)
                      Text(
                        '${quote.price >= prev ? '+' : ''}${formatPercent((quote.price - prev) / prev)} today',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.signed(quote.price - prev),
                        ),
                      ),
                  ],
                ),
                Text(
                  '${quote.symbol} · ${formatDateTime(quote.time)} · '
                  '${dateOnly(quote.time) == dateOnly(DateTime.now()) ? 'today, may be delayed ~15 min' : 'last close (market closed since)'}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () => state.useQuoteAs(InputField.buyPrice),
                      child: const Text('Use as purchase price'),
                    ),
                    OutlinedButton(
                      onPressed: () => state.useQuoteAs(InputField.sellPrice),
                      child: const Text('Use as selling price'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

Future<SymbolMatch?> showSymbolSearch(
  BuildContext context, {
  String initial = '',
}) => showDialog<SymbolMatch>(
  context: context,
  builder: (_) => _SymbolSearchDialog(
    prices: context.read<AppState>().prices,
    initial: initial,
  ),
);

class _SymbolSearchDialog extends StatefulWidget {
  const _SymbolSearchDialog({required this.prices, required this.initial});

  final PriceService prices;
  final String initial;

  @override
  State<_SymbolSearchDialog> createState() => _SymbolSearchDialogState();
}

class _SymbolSearchDialogState extends State<_SymbolSearchDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  Timer? _debounce;
  List<SymbolMatch> _results = const [];
  String? _error;
  bool _loading = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initial.trim().isNotEmpty) _search(widget.initial);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(text));
  }

  Future<void> _search(String text) async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await widget.prices.search(text);
      if (!mounted || request != _request) return;
      setState(() {
        _results = results;
        _loading = false;
        if (results.isEmpty && text.trim().isNotEmpty) {
          _error = 'No NSE/BSE shares found.';
        }
      });
    } on PriceException catch (e) {
      if (!mounted || request != _request) return;
      setState(() {
        _results = const [];
        _loading = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Find a share'),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      content: SizedBox(
        width: 420,
        height: 380,
        child: Column(
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Company name or symbol',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
              onChanged: _onChanged,
              onSubmitted: _search,
            ),
            const SizedBox(height: 8),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Text(_error!, style: theme.textTheme.bodySmall),
              ),
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, i) {
                  final m = _results[i];
                  return ListTile(
                    dense: true,
                    title: Text(
                      m.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(m.symbol),
                    trailing: Chip(
                      label: Text(m.exchange),
                      visualDensity: VisualDensity.compact,
                    ),
                    onTap: () => Navigator.pop(context, m),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
