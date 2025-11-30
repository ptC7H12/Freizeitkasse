import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/auth/event_selection_screen.dart';
import 'utils/constants.dart';

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
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('de', 'DE'),
      ],
      locale: const Locale('de', 'DE'),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppConstants.primaryColor,
          brightness: Brightness.light,
          primary: AppConstants.primaryColor,
          secondary: AppConstants.secondaryColor,
          tertiary: AppConstants.tertiaryColor,
        ),
        useMaterial3: true,

        // AppBar with gradient-ready styling
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: AppConstants.elevationLow,
          backgroundColor: AppConstants.primaryColor,
          foregroundColor: Colors.white,
        ),

        // Cards with subtle elevation and color
        cardTheme: CardThemeData(
          elevation: AppConstants.elevationMedium,
          shadowColor: Colors.black.withOpacity(0.1),
          shape: RoundedRectangleBorder(
            borderRadius: AppConstants.borderRadius16,
          ),
          color: Colors.white,
        ),

        // Input fields with rounded corners
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: AppConstants.borderRadius12,
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: AppConstants.borderRadius12,
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppConstants.borderRadius12,
            borderSide: const BorderSide(color: AppConstants.primaryColor, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: AppConstants.paddingAll16,
        ),

        // Elevated buttons with vibrant colors
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppConstants.primaryColor,
            foregroundColor: Colors.white,
            elevation: AppConstants.elevationLow,
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingXL,
              vertical: AppConstants.spacing,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: AppConstants.borderRadius12,
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
            backgroundColor: AppConstants.secondaryColor,
            foregroundColor: Colors.white,
            elevation: AppConstants.elevationLow,
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spacingXL,
              vertical: AppConstants.spacing,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: AppConstants.borderRadius12,
            ),
          ),
        ),

        // Floating Action Button
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppConstants.primaryColor,
          foregroundColor: Colors.white,
          elevation: AppConstants.elevationMedium,
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
          seedColor: AppConstants.primaryColor,
          brightness: Brightness.dark,
          primary: const Color(0xFF64B5F6),
          secondary: const Color(0xFF81C784),
          tertiary: const Color(0xFFFFB74D),
        ),
        useMaterial3: true,

        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: AppConstants.elevationLow,
          backgroundColor: Color(0xFF1976D2),
          foregroundColor: Colors.white,
        ),
      ),

      // Start with event selection screen
      home: const EventSelectionScreen(),
    );
  }
}
