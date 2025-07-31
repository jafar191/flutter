import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'screens/auth/login_screen.dart';
import 'screens/merchant/merchant_home_screen.dart';
import 'screens/driver/driver_home_screen.dart';
import 'screens/admin/admin_home_screen.dart';
import 'screens/auth/splash_screen.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'جايك للتوصيل',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4CAF50),
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFF4CAF50),
          onPrimary: Colors.white,
          secondary: const Color(0xFFFFA000),
          onSecondary: Colors.white,
          surface: Colors.white,
          onSurface: const Color.fromRGBO(33, 33, 33, 1), // استخدام قيمة RGB لـ black87 لتجنب التحذير
          // تم استبدال 'background' بـ 'surfaceContainer' و 'onBackground' بـ 'onSurfaceVariant'
          surfaceContainer: const Color.fromRGBO(245, 245, 245, 1), // كان Colors.grey[50]
          onSurfaceVariant: const Color.fromRGBO(33, 33, 33, 1), // كان Colors.black87
          error: Colors.red,
          onError: Colors.white,
        ),

        appBarTheme: const AppBarTheme(
          backgroundColor: Color.fromRGBO(245, 245, 245, 1),
          foregroundColor: Color.fromRGBO(33, 33, 33, 1),
          elevation: 0,
          titleTextStyle: TextStyle(
            color: Color.fromRGBO(33, 33, 33, 1),
            fontSize: 20.0,
            fontWeight: FontWeight.bold,
            fontFamily: 'Cairo',
          ),
          iconTheme: IconThemeData(color: Color.fromRGBO(33, 33, 33, 1)),
        ),

        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF4CAF50),
          foregroundColor: Colors.white,
        ),

        cardTheme: CardTheme(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          color: Colors.white,
          margin: const EdgeInsets.all(8.0),
        ),

        buttonTheme: ButtonThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
          buttonColor: const Color(0xFF4CAF50),
          textTheme: ButtonTextTheme.primary,
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            textStyle: const TextStyle(
              fontSize: 16.0,
              fontWeight: FontWeight.bold,
              fontFamily: 'Cairo',
            ),
          ),
        ),

        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF4CAF50),
            textStyle: const TextStyle(
              fontFamily: 'Cairo',
            ),
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color.fromRGBO(245, 245, 245, 1),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: const BorderSide(color: Color(0xFF4CAF50), width: 2.0),
          ),
          hintStyle: const TextStyle(color: Color.fromRGBO(189, 189, 189, 1)),
          contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
        ),

        fontFamily: 'Cairo',
        textTheme: const TextTheme(
          displayLarge: TextStyle(fontSize: 57.0, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
          displayMedium: TextStyle(fontSize: 45.0, fontFamily: 'Cairo'),
          displaySmall: TextStyle(fontSize: 36.0, fontFamily: 'Cairo'),
          headlineLarge: TextStyle(fontSize: 32.0, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
          headlineMedium: TextStyle(fontSize: 28.0, fontFamily: 'Cairo'),
          headlineSmall: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
          titleLarge: TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold, fontFamily: 'Cairo'),
          titleMedium: TextStyle(fontSize: 18.0, fontFamily: 'Cairo'),
          titleSmall: TextStyle(fontSize: 14.0, fontFamily: 'Cairo'),
          bodyLarge: TextStyle(fontSize: 16.0, fontFamily: 'Cairo'),
          bodyMedium: TextStyle(fontSize: 14.0, fontFamily: 'Cairo'),
          bodySmall: TextStyle(fontSize: 12.0, fontFamily: 'Cairo'),
          labelLarge: TextStyle(fontSize: 14.0, fontFamily: 'Cairo'),
          labelMedium: TextStyle(fontSize: 12.0, fontFamily: 'Cairo'),
          labelSmall: TextStyle(fontSize: 11.0, fontFamily: 'Cairo'),
        ),
      ),
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/merchant_home': (context) => const MerchantHomeScreen(),
        '/driver_home': (context) => const DriverHomeScreen(),
        '/admin_home': (context) => const AdminHomeScreen(),
      },
    );
  }
}
