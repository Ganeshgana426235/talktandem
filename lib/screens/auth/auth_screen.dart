import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../theme/app_theme.dart';
import '../../models/auth_provider.dart';

enum AuthStep {
  phoneInput,
  otpInput,
  registrationForm,
  avatarSelection,
}

enum AuthMode {
  login,
  register,
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  // Explicit global reset helper called during logout events to restore clean auth state
  static void resetStaticCaches() {
    print("[TalkTandem AuthUI] Explicit static caches cleared.");
    _persistedMode = AuthMode.login;
    _persistedStep = AuthStep.phoneInput;
    _persistedVerificationId = '';
    _persistedPhone = '';
    _persistedOtp = '';
    _persistedName = '';
    _persistedDob = '';
    _persistedLocation = '';
    _persistedGender = 'Male';
    _persistedInterests = [];
    _persistedAgreedToTerms = false;
    _persistedAvatarUrl = '';
    _otpSentTime = null;
  }

  // Anti-Disposal Preserved State Caching
  static AuthMode _persistedMode = AuthMode.login;
  static AuthStep _persistedStep = AuthStep.phoneInput;
  static String _persistedVerificationId = '';
  static String _persistedPhone = '';
  static String _persistedOtp = '';
  static String _persistedName = '';
  static String _persistedDob = '';
  static String _persistedLocation = '';
  static String _persistedGender = 'Male';
  static List<String> _persistedInterests = [];
  static bool _persistedAgreedToTerms = false;
  static String _persistedAvatarUrl = '';
  static DateTime? _otpSentTime;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  AuthMode _currentMode = AuthMode.login;
  AuthStep _currentStep = AuthStep.phoneInput;
  bool _agreedToTerms = false;
  bool _isSigningIn = false;
  bool _isSavingAccount = false;
  String _verificationId = '';

  late final TextEditingController _phoneController;
  late final TextEditingController _otpController;
  late final TextEditingController _nameController;
  late final TextEditingController _dobController;
  late final TextEditingController _locationController;
  
  final FocusNode _otpFocusNode = FocusNode();

  Timer? _cooldownTimer;
  int _cooldownSeconds = 30;
  bool _canResend = false;

  String _selectedGender = 'Male';
  final List<String> _selectedInterests = [];
  final List<String> _availableInterests = [
    'English Grammar',
    'Vocabulary',
    'Public Speaking',
    'Business English',
    'Interviews Prep',
    'Travel Chat',
    'Movie Reviews',
    'Daily Life',
  ];

  // Local Asset Avatars mapped to your "lib/assets/avatar/" folders
  final List<String> _maleAvatars = List.generate(4, (i) => 'lib/assets/avatar/male/male${i + 1}.png');
  final List<String> _femaleAvatars = List.generate(4, (i) => 'lib/assets/avatar/female/female${i + 1}.png');

  String _selectedAvatarUrl = '';

  @override
  void initState() {
    super.initState();
    print("[TalkTandem AuthUI] AuthScreen initializing. Restoring persistent state.");

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Legacy force logout detection is not available on AuthProvider.
      // Any explicit logout messaging should be handled by the provider or auth flow.
    });

    // Clean start guard: If no active Firebase user is found, force clear stale static caches to avoid UI loop locks
    if (FirebaseAuth.instance.currentUser == null) {
      print("[TalkTandem AuthUI] No active Firebase session detected. Force resetting persistent state to Phone Input.");
      AuthScreen.resetStaticCaches();
    }

    _currentMode = AuthScreen._persistedMode;
    _currentStep = AuthScreen._persistedStep;
    _verificationId = AuthScreen._persistedVerificationId;
    _agreedToTerms = AuthScreen._persistedAgreedToTerms;
    _selectedGender = AuthScreen._persistedGender;
    _selectedInterests.addAll(AuthScreen._persistedInterests);
    _selectedAvatarUrl = AuthScreen._persistedAvatarUrl;

    _phoneController = TextEditingController(text: AuthScreen._persistedPhone);
    _otpController = TextEditingController(text: AuthScreen._persistedOtp);
    _nameController = TextEditingController(text: AuthScreen._persistedName);
    _dobController = TextEditingController(text: AuthScreen._persistedDob);
    _locationController = TextEditingController(text: AuthScreen._persistedLocation);

    _phoneController.addListener(() => AuthScreen._persistedPhone = _phoneController.text);
    _otpController.addListener(() {
      AuthScreen._persistedOtp = _otpController.text;
      _onOtpChanged();
    });
    _nameController.addListener(() => AuthScreen._persistedName = _nameController.text);
    _dobController.addListener(() => AuthScreen._persistedDob = _dobController.text);
    _locationController.addListener(() => AuthScreen._persistedLocation = _locationController.text);

    if (_selectedAvatarUrl.isEmpty) {
      _selectedAvatarUrl = _selectedGender == 'Female' ? _femaleAvatars.first : _maleAvatars.first;
      AuthScreen._persistedAvatarUrl = _selectedAvatarUrl;
    }

    if (AuthScreen._otpSentTime != null) {
      final elapsed = DateTime.now().difference(AuthScreen._otpSentTime!).inSeconds;
      if (elapsed < 30) {
        _cooldownSeconds = 30 - elapsed;
        _canResend = false;
        _startResendTimer(resume: true);
      } else {
        _canResend = true;
      }
    }
  }

  @override
  void dispose() {
    print("[TalkTandem AuthUI] AuthScreen unmounting. Disposing active controllers.");
    _cooldownTimer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    _dobController.dispose();
    _locationController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  void _onOtpChanged() {
    if (_otpController.text.trim().length == 6 && !_isSigningIn) {
      _verifyOtp();
    }
  }

  void _startResendTimer({bool resume = false}) {
    _cooldownTimer?.cancel();
    if (!resume) {
      AuthScreen._otpSentTime = DateTime.now();
      _cooldownSeconds = 30;
      _canResend = false;
    }
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_cooldownSeconds > 0) {
          _cooldownSeconds--;
        } else {
          _canResend = true;
          _cooldownTimer?.cancel();
        }
      });
    });
  }

  String _parseAndCleanPhone(String rawInput) {
    String cleaned = rawInput.replaceAll(RegExp(r'\D'), '');
    if (cleaned.startsWith('0')) {
      cleaned = cleaned.substring(1);
    }
    if (cleaned.startsWith('91') && cleaned.length > 10) {
      cleaned = cleaned.substring(2);
    }
    return '+91$cleaned';
  }

  void _sendOtp() async {
    FocusScope.of(context).unfocus();

    final rawInput = _phoneController.text.trim();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (rawInput.isEmpty) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Please enter your mobile phone number.')),
      );
      return;
    }

    final formattedPhone = _parseAndCleanPhone(rawInput);
    if (formattedPhone.length != 13) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Please enter a valid 10-digit mobile number.')),
      );
      return;
    }

    setState(() => _isSigningIn = true);

    try {
      print("[TalkTandem AuthUI] Initiating OTP send directly to standard FirebaseAuth: $formattedPhone");

      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          try {
            print("[TalkTandem AuthUI] Instant Auto-verification succeeded.");
            // Set registering state to true before signing in to prevent background auto-logout loop
            context.read<AuthProvider>().setRegistering(true);
            final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
            final user = userCredential.user;
            if (user != null && mounted) {
              _processSignInSuccess(user);
            }
          } catch (e) {
            print("[TalkTandem AuthUI] Auto-sign in error: $e");
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          print("[TalkTandem AuthUI] Phone verification failed: ${e.message}");
          if (!mounted) return;
          setState(() => _isSigningIn = false);
          scaffoldMessenger.showSnackBar(
            SnackBar(content: Text('Verification failed: ${e.message}')),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          print("[TalkTandem AuthUI] Direct OTP SMS successfully sent! Verification ID: $verificationId");
          AuthScreen._persistedVerificationId = verificationId;
          AuthScreen._persistedStep = AuthStep.otpInput;
          AuthScreen._otpSentTime = DateTime.now();

          if (!mounted) return;
          setState(() {
            _verificationId = verificationId;
            _currentStep = AuthStep.otpInput;
            _isSigningIn = false;
          });
          _startResendTimer();
          
          Future.delayed(const Duration(milliseconds: 300), () {
            _otpFocusNode.requestFocus();
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
          AuthScreen._persistedVerificationId = verificationId;
        },
        timeout: const Duration(seconds: 30),
      );
    } catch (e) {
      print("[TalkTandem AuthUI] Error initiating phone verification: $e");
      if (!mounted) return;
      setState(() => _isSigningIn = false);
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _verifyOtp() async {
    FocusScope.of(context).unfocus();
    final otpInput = _otpController.text.trim();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (otpInput.length < 6) {
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Please enter a complete 6-digit OTP.')),
      );
      return;
    }

    // Set registering state to true before signing in to prevent background auto-logout loop
    context.read<AuthProvider>().setRegistering(true);
    setState(() => _isSigningIn = true);
    
    try {
      print("[TalkTandem AuthUI] Verifying OTP SMS code: $otpInput");

      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: otpInput,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final user = userCredential.user;

      if (user == null) throw Exception('Authentication failed. Please try again.');
      
      _processSignInSuccess(user);
    } catch (e) {
      print("[TalkTandem AuthUI] Error occurred during verification: $e");
      if (!mounted) return;
      setState(() => _isSigningIn = false);
      
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
      );
    }
  }

  void _processSignInSuccess(User user) async {
    final authProvider = context.read<AuthProvider>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    // Always use authenticated user's phone number if available, otherwise fallback to parsed controller text
    final cleanPhone = user.phoneNumber ?? _parseAndCleanPhone(_phoneController.text);
    AuthScreen._persistedPhone = cleanPhone;

    try {
      final firestore = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'talktandem',
      );
      
      // Point read lookup on Document ID (phone number) - strictly ONE document
      final userDoc = await firestore.collection('users').doc(cleanPhone).get();

      if (!mounted) return;

      if (_currentMode == AuthMode.login) {
        // --- SIGN IN MODE ---
        if (userDoc.exists) {
          print("[TalkTandem AuthUI] Login Mode: Existing User Account confirmed under: $cleanPhone");
          
          final data = userDoc.data();
          // Update the UID field if it was missing
          if (data != null && data['uid'] == null) {
            await firestore.collection('users').doc(cleanPhone).update({'uid': user.uid});
          }

          try {
            // Load user data cleanly using the phone number ID
            await authProvider.loadUserData(cleanPhone);
          } catch (providerError) {
            print("[TalkTandem AuthUI] Non-blocking provider load warning: $providerError");
          }

          // Disable registration status to trigger routing to Home page
          authProvider.setRegistering(false);
          
          if (mounted) {
            setState(() => _isSigningIn = false);
          }
        } else {
          // Account doesn't exist, show custom modal to guide them to registration
          _showNoProfileDialog(user, cleanPhone, authProvider);
        }
      } else {
        // --- REGISTER MODE ---
        if (userDoc.exists) {
          // Profile already exists under this phone, prompt them to Sign In instead
          _showProfileExistsDialog(user, cleanPhone, authProvider);
        } else {
          // Profile is clean and verified, move to setup
          authProvider.setRegistering(true);
          AuthScreen._persistedStep = AuthStep.registrationForm;
          if (mounted) {
            setState(() {
              _currentStep = AuthStep.registrationForm;
              _isSigningIn = false;
            });
          }
        }
      }
    } catch (e) {
      print("[TalkTandem AuthUI] Error checking firestore: $e");
      if (mounted) setState(() => _isSigningIn = false);
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Failed to check profile status: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // Beautiful Custom Dialog shown when a user tries to log in, but no profile document exists
  void _showNoProfileDialog(User user, String cleanPhone, AuthProvider authProvider) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final surface = AppTheme.getSurfaceColor(ctx);
        final textPrimary = AppTheme.getTextColor(ctx);
        final textSecondary = AppTheme.getSecondaryTextColor(ctx);
        
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: surface,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.tealAccent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.userPlus, color: AppTheme.tealAccent, size: 36),
                ),
                const SizedBox(height: 16),
                Text(
                  'Profile Not Found',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary),
                ),
                const SizedBox(height: 12),
                Text(
                  'There is no TalkTandem profile registered under $cleanPhone.\n\nWould you like to register a new account now?',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textSecondary, height: 1.5, fontSize: 14),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await FirebaseAuth.instance.signOut();
                          setState(() {
                            _currentStep = AuthStep.phoneInput;
                            _isSigningIn = false;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppTheme.getBorderColor(context)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Cancel', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          authProvider.setRegistering(true);
                          AuthScreen._persistedMode = AuthMode.register;
                          AuthScreen._persistedStep = AuthStep.registrationForm;
                          setState(() {
                            _currentMode = AuthMode.register;
                            _currentStep = AuthStep.registrationForm;
                            _isSigningIn = false;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.tealAccent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Register', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Beautiful Custom Dialog shown when a user tries to register, but a profile already exists
  void _showProfileExistsDialog(User user, String cleanPhone, AuthProvider authProvider) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final surface = AppTheme.getSurfaceColor(ctx);
        final textPrimary = AppTheme.getTextColor(ctx);
        final textSecondary = AppTheme.getSecondaryTextColor(ctx);
        
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: surface,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.amberPremium.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.alertCircle, color: AppTheme.amberPremium, size: 36),
                ),
                const SizedBox(height: 16),
                Text(
                  'Account Exists',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary),
                ),
                const SizedBox(height: 12),
                Text(
                  'An active profile for $cleanPhone is already registered.\n\nWould you like to Sign In directly to this account?',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textSecondary, height: 1.5, fontSize: 14),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await FirebaseAuth.instance.signOut();
                          setState(() {
                            _currentStep = AuthStep.phoneInput;
                            _isSigningIn = false;
                          });
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppTheme.getBorderColor(context)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text('Cancel', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          try {
                            await authProvider.loadUserData(cleanPhone);
                          } catch (_) {}
                          authProvider.setRegistering(false);
                          if (mounted) {
                            setState(() {
                              _isSigningIn = false;
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.tealAccent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Sign In', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _submitRegistration() {
    FocusScope.of(context).unfocus();
    final name = _nameController.text.trim();
    final dob = _dobController.text.trim();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    if (name.isEmpty) {
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Please enter your full name.')));
      return;
    }
    if (dob.isEmpty) {
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Please enter your date of birth.')));
      return;
    }
    if (!_agreedToTerms) {
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('You must agree to the guidelines.')));
      return;
    }

    AuthScreen._persistedStep = AuthStep.avatarSelection;
    setState(() {
      if (_selectedAvatarUrl.isEmpty || 
          (!_maleAvatars.contains(_selectedAvatarUrl) && _selectedGender == 'Male') ||
          (!_femaleAvatars.contains(_selectedAvatarUrl) && _selectedGender == 'Female')) {
        _selectedAvatarUrl = _selectedGender == 'Female' ? _femaleAvatars.first : _maleAvatars.first;
        AuthScreen._persistedAvatarUrl = _selectedAvatarUrl;
      }
      _currentStep = AuthStep.avatarSelection;
    });
  }

  void _completeRegistration() async {
    print("[TalkTandem AuthUI] Registration transaction starting...");
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    setState(() => _isSavingAccount = true);

    final authProvider = context.read<AuthProvider>();
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;
    
    if (uid != null) {
      final cleanPhone = user?.phoneNumber ?? AuthScreen._persistedPhone;

      try {
        final firestore = FirebaseFirestore.instanceFor(
          app: Firebase.app(),
          databaseId: 'talktandem',
        );

        final profileData = {
          'uid': uid,
          'name': _nameController.text.trim(),
          'dob': _dobController.text.trim(),
          'gender': _selectedGender,
          'location': _locationController.text.trim().isEmpty ? null : _locationController.text.trim(),
          'interests': List<String>.from(_selectedInterests),
          'isSelfieVerified': true,
          'phoneNumber': cleanPhone,
          'avatarUrl': _selectedAvatarUrl,
          'createdAt': FieldValue.serverTimestamp(),
          'streak': 1,
          'maxStreak': 1,
          'xp': 0,
          'isOnline': true,
          'lastOnline': FieldValue.serverTimestamp(),
        };
        
        // Strictly EXACTLY ONE write to the collection profile mapped completely with Phone Number as Doc ID
        await firestore.collection('users').doc(cleanPhone).set(profileData, SetOptions(merge: true));
        print("[TalkTandem AuthUI] Single phone document created under ID: $cleanPhone");

        try {
          // Sync and cache the newly written phone-based profile directly into your local AuthProvider cache FIRST
          await authProvider.loadUserData(cleanPhone);
        } catch (providerError) {
          print("[TalkTandem AuthUI] Non-blocking provider load warning: $providerError");
        }

        // Safely set registering state to false SECOND to trigger clean navigation with fully hydrated state
        authProvider.setRegistering(false);
        
      } catch (e) {
        print("[TalkTandem AuthUI] Critical write error handled inside save: $e");
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Database error: $e'), backgroundColor: Colors.red),
        );
      } finally {
        if (mounted) setState(() => _isSavingAccount = false);
      }
    } else {
      scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Session Expired. Please restart.')));
      AuthScreen._persistedStep = AuthStep.phoneInput;
      setState(() {
        _currentStep = AuthStep.phoneInput;
        _isSavingAccount = false;
      });
    }
  }

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 6205)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 17)),
    );
    if (picked != null) {
      if (!mounted) return;
      setState(() {
        _dobController.text = "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppTheme.getTextColor(context);
    final textSecondary = AppTheme.getSecondaryTextColor(context);
    final surfaceColor = AppTheme.getSurfaceColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.lightBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              if (_currentStep != AuthStep.avatarSelection) ...[
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'lib/assets/logo/tt_logo.png',
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppTheme.tealAccent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(LucideIcons.messageCircle, color: AppTheme.tealAccent, size: 28),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'TalkTandem',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Your premium peer-to-peer English learning community.',
                  style: TextStyle(color: textSecondary, fontSize: 15),
                ),
                const SizedBox(height: 36),
              ],

              _buildStepView(textPrimary, textSecondary, surfaceColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepView(Color textPrimary, Color textSecondary, Color surfaceColor) {
    switch (_currentStep) {
      case AuthStep.phoneInput:
        return _buildPhoneInputView(textPrimary, textSecondary, surfaceColor);
      case AuthStep.otpInput:
        return _buildOtpInputView(textPrimary, textSecondary, surfaceColor);
      case AuthStep.registrationForm:
        return _buildRegistrationView(textPrimary, textSecondary, surfaceColor);
      case AuthStep.avatarSelection:
        return _buildAvatarSelectionView(textPrimary, textSecondary, surfaceColor);
    }
  }

  Widget _buildPhoneInputView(Color textPrimary, Color textSecondary, Color surfaceColor) {
    final titleText = _currentMode == AuthMode.login ? 'Welcome Back' : 'Create Account';
    final descText = _currentMode == AuthMode.login 
        ? 'Sign in to connect with your peer learning community.' 
        : 'Register a profile to find your perfect English practice partners.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mode segmented switcher
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.getBorderColor(context)),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentMode = AuthMode.login;
                      AuthScreen._persistedMode = AuthMode.login;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _currentMode == AuthMode.login ? AppTheme.tealAccent : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Sign In',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _currentMode == AuthMode.login ? Colors.white : textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentMode = AuthMode.register;
                      AuthScreen._persistedMode = AuthMode.register;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _currentMode == AuthMode.register ? AppTheme.tealAccent : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Register',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _currentMode == AuthMode.register ? Colors.white : textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        Text(
          titleText,
          style: TextStyle(fontSize: 24, fontStyle: FontStyle.normal, fontWeight: FontWeight.bold, color: textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          descText,
          style: TextStyle(color: textSecondary),
        ),
        const SizedBox(height: 32),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.getBorderColor(context)),
          ),
          child: Row(
            children: [
              Text(
                '+91',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textPrimary),
              ),
              const SizedBox(width: 12),
              Container(width: 1, height: 24, color: AppTheme.getBorderColor(context)),
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: TextStyle(color: textPrimary),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Enter 10 digit number',
                    hintStyle: TextStyle(color: textSecondary.withOpacity(0.6)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isSigningIn ? null : _sendOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.tealAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isSigningIn
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    'Get OTP Code',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
          ),
        ),
        
        const SizedBox(height: 32),
        Center(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.tealAccent.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.tealAccent.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.textSelect, color: AppTheme.tealAccent, size: 18),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "Secure Authentication: standard Firebase Phone Auth rules apply.",
                    style: TextStyle(fontSize: 12, color: textSecondary, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtpInputView(Color textPrimary, Color textSecondary, Color surfaceColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            AuthScreen._persistedStep = AuthStep.phoneInput;
            setState(() => _currentStep = AuthStep.phoneInput);
          },
          child: Row(
            children: const [
              Icon(LucideIcons.arrowLeft, color: AppTheme.tealAccent, size: 18),
              SizedBox(width: 8),
              Text('Back', style: TextStyle(color: AppTheme.tealAccent, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Verification Code',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          "We've sent a 6-digit confirmation code to +91 ${_phoneController.text.trim()}.",
          style: TextStyle(color: textSecondary),
        ),
        const SizedBox(height: 32),

        GestureDetector(
          onTap: () {
            _otpFocusNode.requestFocus();
          },
          child: Stack(
            children: [
              Opacity(
                opacity: 0.0,
                child: SizedBox(
                  height: 1,
                  width: 1,
                  child: TextField(
                    controller: _otpController,
                    focusNode: _otpFocusNode,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(counterText: ""),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (index) {
                  String digit = "";
                  if (_otpController.text.length > index) {
                    digit = _otpController.text[index];
                  }
                  
                  bool isFocused = _otpController.text.length == index && _otpFocusNode.hasFocus;
                  
                  return Container(
                    width: 48,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isFocused ? AppTheme.tealAccent : AppTheme.getBorderColor(context),
                        width: isFocused ? 2 : 1.5,
                      ),
                    ),
                    child: Text(
                      digit,
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary),
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isSigningIn ? null : _verifyOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.tealAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isSigningIn
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    'Verify & Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: _canResend
              ? TextButton(
                  onPressed: _isSigningIn ? null : _sendOtp,
                  child: const Text(
                    "Resend Code",
                    style: TextStyle(color: AppTheme.tealAccent, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                )
              : Text(
                  "Resend code in $_cooldownSeconds s",
                  style: TextStyle(color: textSecondary, fontSize: 13),
                ),
        )
      ],
    );
  }

  Widget _buildRegistrationView(Color textPrimary, Color textSecondary, Color surfaceColor) {
    final borderColor = AppTheme.getBorderColor(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Setup Profile',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textPrimary),
        ),
        const SizedBox(height: 8),
        Text(
          'Help us personalize your peer-to-peer english practice pairings.',
          style: TextStyle(color: textSecondary),
        ),
        const SizedBox(height: 24),

        Text('Full Name', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: TextField(
            controller: _nameController,
            style: TextStyle(color: textPrimary),
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'e.g. Rahul Sharma',
              hintStyle: TextStyle(color: textSecondary.withOpacity(0.5)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 16),

        Text('Date of Birth (17+ years rules)', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _selectDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _dobController.text.isEmpty ? 'Select DOB' : _dobController.text,
                  style: TextStyle(
                    color: _dobController.text.isEmpty ? textSecondary.withOpacity(0.5) : textPrimary,
                    fontSize: 16,
                  ),
                ),
                const Icon(LucideIcons.calendar, color: AppTheme.tealAccent, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        Text('Gender', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  AuthScreen._persistedGender = 'Male';
                  setState(() {
                    _selectedGender = 'Male';
                    _selectedAvatarUrl = _maleAvatars.first;
                    AuthScreen._persistedAvatarUrl = _selectedAvatarUrl;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _selectedGender == 'Male' ? AppTheme.tealAccent.withOpacity(0.15) : surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedGender == 'Male' ? AppTheme.tealAccent : borderColor,
                      width: _selectedGender == 'Male' ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.user, color: _selectedGender == 'Male' ? AppTheme.tealAccent : textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        'Male',
                        style: TextStyle(
                          color: _selectedGender == 'Male' ? AppTheme.tealAccent : textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  AuthScreen._persistedGender = 'Female';
                  setState(() {
                    _selectedGender = 'Female';
                    _selectedAvatarUrl = _femaleAvatars.first;
                    AuthScreen._persistedAvatarUrl = _selectedAvatarUrl;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: _selectedGender == 'Female' ? AppTheme.tealAccent.withOpacity(0.15) : surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedGender == 'Female' ? AppTheme.tealAccent : borderColor,
                      width: _selectedGender == 'Female' ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.user, color: _selectedGender == 'Female' ? AppTheme.tealAccent : textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        'Female',
                        style: TextStyle(
                          color: _selectedGender == 'Female' ? AppTheme.tealAccent : textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Text('Location (Optional)', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: TextField(
            controller: _locationController,
            style: TextStyle(color: textPrimary),
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'e.g. Mumbai, India',
              hintStyle: TextStyle(color: textSecondary.withOpacity(0.5)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
        const SizedBox(height: 16),

        Text('Conversational Interests', style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableInterests.map((interest) {
            final isSelected = _selectedInterests.contains(interest);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedInterests.remove(interest);
                    AuthScreen._persistedInterests.remove(interest);
                  } else {
                    _selectedInterests.add(interest);
                    AuthScreen._persistedInterests.add(interest);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.tealAccent : surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isSelected ? AppTheme.tealAccent : borderColor),
                ),
                child: Text(
                  interest,
                  style: TextStyle(
                    color: isSelected ? Colors.white : textPrimary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: _agreedToTerms,
              onChanged: (val) {
                AuthScreen._persistedAgreedToTerms = val ?? false;
                setState(() {
                  _agreedToTerms = val ?? false;
                });
              },
              activeColor: AppTheme.tealAccent,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Text(
                  'I certify that I am 17+ and agree to practice under the Community Safety Guidelines and Indian IT Rules.',
                  style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _agreedToTerms ? _submitRegistration : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _agreedToTerms ? AppTheme.tealAccent : Colors.grey,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text(
              'Choose Avatar & Continue',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildAvatarSelectionView(Color textPrimary, Color textSecondary, Color surfaceColor) {
    final activeAvatarList = _selectedGender == 'Female' ? _femaleAvatars : _maleAvatars;

    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () {
                  AuthScreen._persistedStep = AuthStep.registrationForm;
                  setState(() => _currentStep = AuthStep.registrationForm);
                },
                child: Row(
                  children: const [
                    Icon(LucideIcons.arrowLeft, color: AppTheme.tealAccent, size: 18),
                    SizedBox(width: 8),
                    Text('Back', style: TextStyle(color: AppTheme.tealAccent, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.tealAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.user, color: AppTheme.tealAccent, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      _selectedGender.toUpperCase(),
                      style: const TextStyle(color: AppTheme.tealAccent, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Select Your Avatar',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose an avatar to complete setting up your peer profile.',
            textAlign: TextAlign.center,
            style: TextStyle(color: textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 32),

          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.tealAccent, width: 3.5),
              boxShadow: [
                BoxShadow(color: AppTheme.tealAccent.withOpacity(0.25), blurRadius: 16, spreadRadius: 2)
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(80),
              child: Image.asset(
                _selectedAvatarUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: surfaceColor,
                    child: const Icon(LucideIcons.user, size: 60, color: AppTheme.tealAccent),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 36),

          Text(
            'Available ${_selectedGender} Avatars',
            style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.0,
            ),
            itemCount: activeAvatarList.length,
            itemBuilder: (context, index) {
              final avatarUrl = activeAvatarList[index];
              final isSelected = _selectedAvatarUrl == avatarUrl;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedAvatarUrl = avatarUrl;
                    AuthScreen._persistedAvatarUrl = avatarUrl;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppTheme.tealAccent : Colors.transparent,
                      width: 4,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: Image.asset(
                      avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: surfaceColor,
                          child: Icon(LucideIcons.user, color: textSecondary),
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 48),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isSavingAccount ? null : _completeRegistration,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.tealAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isSavingAccount
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Complete Profile Setup',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}