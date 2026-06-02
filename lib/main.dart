import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'models/auth_provider.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("Firebase initialized successfully using default instance settings.");
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const DosttConnectApp(),
    ),
  );
}

class DosttConnectApp extends StatelessWidget {
  const DosttConnectApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TalkTandem',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    // If still resolving auth status, show a beautiful loading state
    if (authProvider.isLoading && authProvider.currentUser == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).brightness == Brightness.dark 
            ? AppTheme.darkBackground 
            : AppTheme.lightBackground,
        body: const Center(
          child: CircularProgressIndicator(
            color: AppTheme.tealAccent,
          ),
        ),
      );
    }

    // Authenticated and profile is loaded
    if (authProvider.isAuthenticated && authProvider.userData != null) {
      return const HomeScreen();
    }

    // Not logged in or requires profile registration
    return const AuthScreen();
  }
}