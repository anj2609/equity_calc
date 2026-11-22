import 'dart:convert';

import 'package:http/http.dart' as http;

class SymbolMatch {
  const SymbolMatch({
    required this.symbol,
    required this.name,
    required this.exchange,
  });

  final String symbol;
  final String name;

  /// "NSE" or "BSE".
  final String exchange;
}

class Quote {
  const Quote({
    required this.symbol,
    required this.price,
    required this.time,
    this.name,
    this.previousClose,
  });

  final String symbol;
  final double price;
  final DateTime time;
  final String? name;
  final double? previousClose;
}

class PriceException implements Exception {
  const PriceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Looks up NSE/BSE symbols and last traded prices from Yahoo Finance's
/// public endpoints. Unofficial: prices can be delayed and the service can
/// change without notice, so every call fails soft with a [PriceException].
class PriceService {
  PriceService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _headers = {
    'User-Agent': 'Mozilla/5.0 (EquityCalc)',
    'Accept': 'application/json',
  };
  static const _timeout = Duration(seconds: 10);

  Future<List<SymbolMatch>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final uri = Uri.https('query2.finance.yahoo.com', '/v1/finance/search', {
      'q': q,
      'quotesCount': '12',
      'newsCount': '0',
    });
    final json = await _get(uri);
    final quotes = (json['quotes'] as List?) ?? const [];
    final matches = <SymbolMatch>[];
    for (final raw in quotes.whereType<Map>()) {
      final symbol = raw['symbol']?.toString() ?? '';
      final exchange = _exchange(symbol);
      if (exchange == null) continue;
      matches.add(
        SymbolMatch(
          symbol: symbol,
          name: (raw['longname'] ?? raw['shortname'] ?? symbol).toString(),
          exchange: exchange,
        ),
      );
    }
    return matches;
  }

  /// [symbol] like "RELIANCE.NS". A bare "RELIANCE" is treated as NSE.
  Future<Quote> quote(String symbol) async {
    final s = normaliseSymbol(symbol);
    if (s.isEmpty) throw const PriceException('Enter a symbol first.');
    final uri = Uri.https('query1.finance.yahoo.com', '/v8/finance/chart/$s', {
      'interval': '1d',
      'range': '1d',
    });
    final json = await _get(uri);
    final results = (json['chart'] as Map?)?['result'] as List?;
    final meta = results == null || results.isEmpty
        ? null
        : (results.first as Map)['meta'] as Map?;
    final price = (meta?['regularMarketPrice'] as num?)?.toDouble();
    if (meta == null || price == null) {
      throw PriceException('No price found for $s.');
    }
    final seconds = (meta['regularMarketTime'] as num?)?.toInt();
    return Quote(
      symbol: s,
      price: price,
      time: seconds == null
          ? DateTime.now()
          : DateTime.fromMillisecondsSinceEpoch(seconds * 1000),
      name: (meta['longName'] ?? meta['shortName'])?.toString(),
      previousClose: (meta['chartPreviousClose'] as num?)?.toDouble(),
    );
  }

  static String normaliseSymbol(String symbol) {
    final s = symbol.trim().toUpperCase();
    if (s.isEmpty || s.contains('.')) return s;
    return '$s.NS';
  }

  static String? _exchange(String symbol) {
    if (symbol.endsWith('.NS')) return 'NSE';
    if (symbol.endsWith('.BO')) return 'BSE';
    return null;
  }

  Future<Map<String, dynamic>> _get(Uri uri) async {
    final http.Response res;
    try {
      res = await _client.get(uri, headers: _headers).timeout(_timeout);
    } catch (_) {
      throw const PriceException(
        'Could not reach the price service. Check your internet connection.',
      );
    }
    if (res.statusCode == 404) throw const PriceException('Symbol not found.');
    if (res.statusCode != 200) {
      throw PriceException(
        'Price service error (${res.statusCode}). Try again later.',
      );
    }
    try {
      return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    } catch (_) {
      throw const PriceException('Unexpected reply from the price service.');
    }
  }
}
