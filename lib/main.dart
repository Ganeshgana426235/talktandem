import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:permission_handler/permission_handler.dart';

import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'models/auth_provider.dart';
import 'services/iap_service.dart'; // Import your InAppPurchaseService
import 'screens/auth/auth_screen.dart';
import 'screens/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("Firebase initialized successfully using default instance settings.");
    await MobileAds.instance.initialize();
    debugPrint("Google Mobile Ads initialized successfully.");
  } catch (e) {
    debugPrint("Firebase/MobileAds initialization failed: $e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        // Registered global IAP Service with automated store api initialization cascade
        ChangeNotifierProvider(create: (_) => InAppPurchaseService()..initialize()),
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

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _hasCheckedPermissions = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authProvider = context.watch<AuthProvider>();

    // Trigger permission requests as soon as the user is verified and authenticated
    if (authProvider.isAuthenticated && authProvider.userData != null && !_hasCheckedPermissions) {
      _hasCheckedPermissions = true;
      _requestAppPermissions();
    }
  }

  Future<void> _requestAppPermissions() async {
    // 1. Request Microphone permission for voice match calls
    PermissionStatus micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      debugPrint("[PERMISSIONS] Requesting hardware access: Microphone");
      await Permission.microphone.request();
    }

    // 2. Request Notification permission for matching alerts
    PermissionStatus notificationStatus = await Permission.notification.status;
    if (!notificationStatus.isGranted) {
      debugPrint("[PERMISSIONS] Requesting system access: Notifications");
      await Permission.notification.request();
    }
  }

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