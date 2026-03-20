import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models/app_state.dart';
import 'pages/dashboard_page.dart';
import 'pages/connection_page.dart';
import 'pages/records_page.dart';
import 'pages/gps_page.dart';
import 'views/controller_page.dart';
import 'views/settings_page.dart';
import 'views/selection_page.dart';
import 'pages/device_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MyAppState(),
      child: MaterialApp(
        title: 'Stroller Remote Control',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        initialRoute: '/dashboard',
        routes: {
          '/dashboard': (context) => const DashboardPage(),
          '/connect': (context) => const ConnectionPage(),
          '/records': (context) => const RecordsPage(),
          '/gps': (context) => const GpsPage(),
          '/control': (context) => const ControllerPage(),
          '/settings': (context) => const SettingsPage(),
          '/select': (context) => const SelectionPage(),
          '/device': (context) => const DevicePage(),
        },
      ),
    );
  }
}
