import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/auth/event_selection_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize German locale for date formatting
  await initializeDateFormatting('de_DE', null);

  runApp(
    const ProviderScope(
      child: MGBFreizeitplanerApp(),
    ),
  );
}

class MGBFreizeitplanerApp extends StatelessWidget {
  const MGBFreizeitplanerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MGB Freizeitplaner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3), // Material Blue
          brightness: Brightness.light,
          primary: const Color(0xFF2196F3),
          secondary: const Color(0xFF4CAF50), // Green for positive actions
          tertiary: const Color(0xFFFF9800), // Orange for warnings/highlights
        ),
        useMaterial3: true,

        // AppBar with gradient-ready styling
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 2,
          backgroundColor: Color(0xFF2196F3),
          foregroundColor: Colors.white,
        ),

        // Cards with subtle elevation and color
        cardTheme: CardThemeData(
          elevation: 3,
          shadowColor: Colors.black.withOpacity(0.1),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          color: Colors.white,
        ),

        // Input fields with rounded corners
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2196F3), width: 2),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),

        // Elevated buttons with vibrant colors
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2196F3),
            foregroundColor: Colors.white,
            elevation: 2,
            padding: const EdgeInsets.symmetric(
              horizontal: 32,
              vertical: 16,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),

        // Filled buttons (secondary style)
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            foregroundColor: Colors.white,
            elevation: 2,
            padding: const EdgeInsets.symmetric(
              horizontal: 32,
              vertical: 16,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        // Floating Action Button
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF2196F3),
          foregroundColor: Colors.white,
          elevation: 4,
        ),

        // Drawer theme
        drawerTheme: DrawerThemeData(
          backgroundColor: Colors.white,
          elevation: 16,
          shadowColor: Colors.black.withOpacity(0.2),
        ),
      ),

      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2196F3),
          brightness: Brightness.dark,
          primary: const Color(0xFF64B5F6),
          secondary: const Color(0xFF81C784),
          tertiary: const Color(0xFFFFB74D),
        ),
        useMaterial3: true,

        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 2,
          backgroundColor: Color(0xFF1976D2),
          foregroundColor: Colors.white,
        ),
      ),

      // Start with event selection screen
      home: const EventSelectionScreen(),
    );
  }
}
