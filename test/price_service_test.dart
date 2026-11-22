import 'dart:convert';

import 'package:equity_calc/services/price_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Canned Yahoo replies so tests don't depend on the network.
http.Client fakeYahoo({int status = 200}) => MockClient((req) async {
  if (status != 200) return http.Response('', status);
  if (req.url.path.startsWith('/v8/finance/chart/')) {
    final symbol = req.url.pathSegments.last;
    return http.Response(
      jsonEncode({
        'chart': {
          'result': [
            {
              'meta': {
                'symbol': symbol,
                'regularMarketPrice': 1377.5,
                'regularMarketTime': 1795168690,
                'chartPreviousClose': 1375.6,
                'longName': 'Reliance Industries Limited',
              },
            },
          ],
        },
      }),
      200,
    );
  }
  return http.Response(
    jsonEncode({
      'quotes': [
        {'symbol': 'RELIANCE.NS', 'longname': 'Reliance Industries Limited'},
        {'symbol': 'RELIANCE.BO', 'shortname': 'RELIANCE INDUSTRIES'},
        {'symbol': 'RIGD.IL', 'shortname': 'Reliance GDR'},
      ],
    }),
    200,
  );
});

void main() {
  test(
    'quote parses price, time and name; bare symbols default to NSE',
    () async {
      final q = await PriceService(client: fakeYahoo()).quote('reliance');
      expect(q.symbol, 'RELIANCE.NS');
      expect(q.price, 1377.5);
      expect(q.previousClose, 1375.6);
      expect(q.name, 'Reliance Industries Limited');
      expect(q.time, DateTime.fromMillisecondsSinceEpoch(1795168690 * 1000));
    },
  );

  test('search keeps only NSE and BSE listings', () async {
    final results = await PriceService(client: fakeYahoo()).search('reliance');
    expect(results.map((m) => m.symbol), ['RELIANCE.NS', 'RELIANCE.BO']);
    expect(results.map((m) => m.exchange), ['NSE', 'BSE']);
  });

  test('errors become a readable PriceException', () async {
    expect(
      () => PriceService(client: fakeYahoo(status: 404)).quote('NOPE.NS'),
      throwsA(
        isA<PriceException>().having(
          (e) => e.message,
          'message',
          'Symbol not found.',
        ),
      ),
    );
    expect(
      () => PriceService(client: fakeYahoo()).quote('  '),
      throwsA(isA<PriceException>()),
    );
  });
}
