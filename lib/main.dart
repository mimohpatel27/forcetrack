import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/mock_data_service.dart';
import 'services/pi_connection_service.dart';
import 'screens/connection_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/temperature_screen.dart';

// ─────────────────────────────────────────
// ONE FLAG — flip to false when Pi is ready
// ─────────────────────────────────────────
const bool useMock = true;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PiConnectionService()),
        Provider<MockDataService>(
          create: (_) {
            final svc = MockDataService();
            if (useMock) svc.start();
            return svc;
          },
          dispose: (_, svc) => svc.dispose(),
        ),
      ],
      child: const ForceTrackApp(),
    ),
  );
}

class ForceTrackApp extends StatelessWidget {
  const ForceTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ForceTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1D9E75)),
        fontFamily: 'Inter',
        useMaterial3: true,
      ),
      home: useMock ? const AppShell() : const ConnectionScreen(),
    );
  }
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _screens = [
    DashboardScreen(),
    TemperatureScreen(),
    ConnectionScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: Colors.white,
        elevation: 0,
        indicatorColor: const Color(0xFFE1F5EE),
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: Color(0xFF1D9E75)),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.thermostat_outlined),
            selectedIcon:
                Icon(Icons.thermostat, color: Color(0xFF1D9E75)),
            label: 'Temperature',
          ),
          NavigationDestination(
            icon: Icon(Icons.wifi_outlined),
            selectedIcon: Icon(Icons.wifi, color: Color(0xFF1D9E75)),
            label: 'Connect',
          ),
        ],
      ),
    );
  }
}