import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'state/app_state.dart';
import 'ui/home_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = await AppState.load();
  runApp(
    ChangeNotifierProvider.value(value: state, child: const EquityCalcApp()),
  );
}

class EquityCalcApp extends StatelessWidget {
  const EquityCalcApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeMode = context.select<AppState, ThemeMode>(
      (s) => s.settings.themeMode,
    );
    return MaterialApp(
      title: 'Equity Return Calculator',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: themeMode,
      home: const HomeScreen(),
    );
  }
}
