import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/storage_service.dart';
import 'utils/themes.dart';
import 'utils/app_localizations.dart';
import 'screens/home_screen.dart';
import 'screens/calculator_screen.dart';
import 'screens/customers_screen.dart';
import 'screens/khata_screen.dart';
import 'screens/bills_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (e) {
    debugPrint('SharedPreferences init failed: $e');
  }
  
  // AdMob completely disabled - causing crash after 2 seconds
  // Will be re-enabled with proper native crash handling
  // For now, app runs without ads (no income, but no crash)
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => StorageService(prefs)),
      ],
      child: const NoteCounterProApp(),
    ),
  );
}

class NoteCounterProApp extends StatelessWidget {
  const NoteCounterProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<StorageService>(
      builder: (context, storage, child) {
        return LocalizationProvider(
          languageCode: storage.languageCode,
          child: MaterialApp(
            title: 'Note Counter Pro',
            debugShowCheckedModeBanner: false,
            theme: AppThemes.lightTheme,
            darkTheme: AppThemes.darkTheme,
            themeMode: storage.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            home: const MainScaffold(),
          ),
        );
      },
    );
  }
}

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  int _currentIndex = 0;
  
  @override
  Widget build(BuildContext context) {
    final storage = context.watch<StorageService>();
    final currencyCode = storage.defaultCurrency;
    final loc = context.loc;
    
    final List<Widget> _screens = [
      const HomeScreen(),
      CalculatorScreen(currencyCode: currencyCode),
      const KhataScreen(),
      const SettingsScreen(),
    ];
    
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.calculate_outlined),
            selectedIcon: const Icon(Icons.calculate),
            label: loc.t('counter'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.functions_outlined),
            selectedIcon: const Icon(Icons.functions),
            label: loc.t('calculator'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: const Icon(Icons.account_balance_wallet),
            label: loc.t('khata'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: loc.t('settings'),
          ),
        ],
      ),
    );
  }
}
