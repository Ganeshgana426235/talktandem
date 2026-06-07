import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../models/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../premium/premium_plans_screen.dart';

class AiCallScreen extends StatefulWidget {
  final String topic;

  const AiCallScreen({super.key, required this.topic});

  @override
  State<AiCallScreen> createState() => _AiCallScreenState();
}

class _AiCallScreenState extends State<AiCallScreen> with SingleTickerProviderStateMixin {
  late final String _aiName;
  late final String _aiTitle;
  
  int _secondsElapsed = 0;
  Timer? _timer;
  late AnimationController _waveController;

  bool _isMuted = false;
  bool _isSpeaker = true;

  int _startDailySeconds = 0;
  bool _isPremium = false;

  // Dialog Steps representing spoken prompts
  final Map<String, List<String>> _spokenPrompts = {
    'Job Interview Prep': [
      "Let's practice! Can you tell me a little bit about yourself and your professional background?",
      "Interesting! Why are you interested in this position, and what unique value do you bring?",
      "Describe a difficult situation you faced in your last job and how you handled it.",
      "Good answer. What are your long-term career goals for the next five years?",
      "That is all for today's mock interview. You did great! Hang up to save your stats."
    ],
    'Daily Talk': [
      "Hey! Let's talk. What did you eat for breakfast today? Was it healthy?",
      "Nice. Do you have any plans to watch movies, play sports, or meet friends later?",
      "I love that. Tell me about your favorite hobby and how you got started with it.",
      "That sounds so relaxing. It is important to find balance.",
      "Wonderful speaking practice today. Let's practice again tomorrow!"
    ],
    'Favorite Food': [
      "Hello! Chef Marco here. What is your favorite dish to eat when you feel happy?",
      "Mmm, sounds delicious! Do you prefer cooking at home or ordering takeout?",
      "Cooking is a great skill! What is a popular street food in your home country?",
      "Wow, I need to try that! Sounds amazing.",
      "It was a pleasure talking about food. Hang up to complete your session!"
    ],
    'Travel Plans': [
      "Hey explorer! If you had an unlimited travel budget, which country would you visit first?",
      "Wow, a dream trip! Would you travel solo, or with your friends and family?",
      "Solo or shared, travel always expands your mind. What is the best beach or mountain you've ever seen?",
      "Beautiful! I can picture it in my mind right now.",
      "Hope you get to travel there soon. Great practice today!"
    ]
  };

  int _currentStep = 0;
  String _currentCaption = "";

  @override
  void initState() {
    super.initState();
    _setupPersona();
    
    // Fetch initial limits mapping for limits tracker
    final auth = context.read<AuthProvider>();
    final today = "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}";
    if (auth.userData?['lastCallDate'] == today) {
      _startDailySeconds = (auth.userData?['dailyTalkSeconds'] as num?)?.toInt() ?? 0;
    }
    _isPremium = (auth.userData?['isPremium'] as bool?) ?? false;

    _startTimer();
    
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    // Initial subtitle caption
    final prompts = _spokenPrompts[widget.topic];
    if (prompts != null && prompts.isNotEmpty) {
      _currentCaption = prompts[0];
    } else {
      _currentCaption = "Hello! Let's start practicing our spoken English.";
    }
  }

  void _setupPersona() {
    switch (widget.topic) {
      case 'Job Interview Prep':
        _aiName = "Sophia H. (HR)";
        _aiTitle = "Interview Simulator";
        break;
      case 'Daily Talk':
        _aiName = "Chloe";
        _aiTitle = "Conversation Peer";
        break;
      case 'Favorite Food':
        _aiName = "Chef Marco";
        _aiTitle = "Culinary Companion";
        break;
      case 'Travel Plans':
        _aiName = "Leo";
        _aiTitle = "Travel Advisor";
        break;
      default:
        _aiName = "Tandem AI";
        _aiTitle = "Learning Coach";
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _secondsElapsed++;

          // 60 Min (1 Hour) Global Daily Free Limit Check
          if (!_isPremium && (_startDailySeconds + _secondsElapsed) >= 60 * 60) {
            _handleDailyLimitReached();
          }
        });
      }
    });
  }

  String _getFormattedTime() {
    final m = (_secondsElapsed ~/ 60).toString().padLeft(2, '0');
    final s = (_secondsElapsed % 60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  void _advancePrompt() {
    final prompts = _spokenPrompts[widget.topic];
    if (prompts == null) return;

    if (_currentStep < prompts.length - 1) {
      setState(() {
        _currentStep++;
        _currentCaption = prompts[_currentStep];
      });
      // Award micro Coins for moving forward
      final auth = context.read<AuthProvider>();
      auth.firestore.awardCoins(auth.uid ?? '', 1);
    } else {
      setState(() {
        _currentCaption = "Session completed! Tap the red phone to finish.";
      });
    }
  }

  void _endCall() async {
    _timer?.cancel();
    _waveController.dispose();

    final auth = context.read<AuthProvider>();
    final phone = auth.userData?['phoneNumber'] ?? FirebaseAuth.instance.currentUser?.phoneNumber;
    
    if (phone != null && _secondsElapsed > 5) {
      try {
        final now = DateTime.now();
        final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
        // Call duration in minutes (minimum 1 minute if call took place)
        final minutes = (_secondsElapsed ~/ 60).clamp(1, 999);

        // Calculate coins based on call duration:
        // - Less than 1 minute (60 seconds) = exactly 1 coin.
        // - 1 minute or more = minutes * random multiplier of 1, 2, or 3.
        int coinsEarned = 1;
        if (_secondsElapsed >= 60) {
          final int calculatedMins = _secondsElapsed ~/ 60;
          final int multiplier = Random().nextInt(3) + 1; // 1, 2, or 3
          coinsEarned = calculatedMins * multiplier;
          print("[TalkTandem AI Call] Call ended. Talked for $_secondsElapsed seconds ($calculatedMins mins). Multiplier chosen: $multiplier. Total coins earned: $coinsEarned");
        } else {
          print("[TalkTandem AI Call] Call ended. Talked for less than 1 min ($_secondsElapsed seconds). Coins earned: 1");
        }

        final firestore = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'talktandem');
        
        // Call secure Cloud Function instead of client-side updates
        print("[TalkTandem AI Call] Calling endAiCallSession Cloud Function for phone: $phone...");
        await auth.firestore.endAiCallSession(
          durationSeconds: _secondsElapsed,
          coinsEarned: coinsEarned,
          dateStr: todayStr,
        );

        // Generate a unique call ID for the AI call
        final String aiCallId = "ai_call_${DateTime.now().millisecondsSinceEpoch}";
        
        final callHistoryData = {
          'callId': aiCallId,
          'participantIds': [phone, 'ai'],
          'participantNames': {phone: auth.userData?['name'] ?? 'User', 'ai': 'AI - ${widget.topic}'},
          'participantAvatars': {
            phone: auth.userData?['avatarUrl'],
            'ai': null
          },
          'status': 'ended',
          'startedAt': Timestamp.fromDate(now.subtract(Duration(seconds: _secondsElapsed))),
          'endedAt': FieldValue.serverTimestamp(),
          'durationMinutes': minutes,
        };

        // 1. Write to nested call_history subcollection (Personal History) - allowed by rules
        await firestore.collection('users').doc(phone).collection('call_history').doc(aiCallId).set(callHistoryData);

        // 2. Write to GLOBAL call_history collection (Global History) - allowed by rules
        await firestore.collection('call_history').doc(aiCallId).set(callHistoryData);

        // Sync local provider data
        await auth.loadUserData(phone);
      } catch (e) {
        debugPrint("[AI Call End] Failed to sync call stats: $e");
      }
    }

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI Practice Session Saved!'), backgroundColor: AppTheme.tealAccent),
      );
    }
  }

  void _handleDailyLimitReached() async {
    _timer?.cancel();
    try {
      _waveController.dispose();
    } catch (_) {}

    final auth = context.read<AuthProvider>();
    final phone = auth.userData?['phoneNumber'] ?? FirebaseAuth.instance.currentUser?.phoneNumber;
    
    if (phone != null && _secondsElapsed > 5) {
      try {
        final now = DateTime.now();
        final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
        final minutes = (_secondsElapsed ~/ 60).clamp(1, 999);

        int coinsEarned = 1;
        if (_secondsElapsed >= 60) {
          final int calculatedMins = _secondsElapsed ~/ 60;
          final int multiplier = Random().nextInt(3) + 1;
          coinsEarned = calculatedMins * multiplier;
        }

        final firestore = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'talktandem');
        
        // Call secure Cloud Function instead of client-side updates
        print("[TalkTandem AI Call] Calling endAiCallSession Cloud Function for daily limit...");
        await auth.firestore.endAiCallSession(
          durationSeconds: _secondsElapsed,
          coinsEarned: coinsEarned,
          dateStr: todayStr,
        );

        final String aiCallId = "ai_call_${DateTime.now().millisecondsSinceEpoch}";
        final callHistoryData = {
          'callId': aiCallId,
          'participantIds': [phone, 'ai'],
          'participantNames': {phone: auth.userData?['name'] ?? 'User', 'ai': 'AI - ${widget.topic}'},
          'participantAvatars': {phone: auth.userData?['avatarUrl'], 'ai': null},
          'status': 'ended',
          'startedAt': Timestamp.fromDate(now.subtract(Duration(seconds: _secondsElapsed))),
          'endedAt': FieldValue.serverTimestamp(),
          'durationMinutes': minutes,
        };

        // 1. Write to nested call_history subcollection (Personal History) - allowed by rules
        await firestore.collection('users').doc(phone).collection('call_history').doc(aiCallId).set(callHistoryData);
        // 2. Write to GLOBAL call_history collection (Global History) - allowed by rules
        await firestore.collection('call_history').doc(aiCallId).set(callHistoryData);

        await auth.loadUserData(phone);
      } catch (e) {
        debugPrint("[AI Call Limit End] Failed to sync call stats: $e");
      }
    }

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          final surface = AppTheme.getSurfaceColor(ctx);
          final textPrimary = AppTheme.getTextColor(ctx);
          final textSecondary = AppTheme.getSecondaryTextColor(ctx);
          return AlertDialog(
            backgroundColor: surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(LucideIcons.crown, color: AppTheme.amberPremium, size: 28),
                const SizedBox(width: 10),
                Text(
                  'Daily Limit Reached',
                  style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Text(
              'Your daily free practice limit of 60 minutes has been completed. Upgrade to premium for unlimited calls!',
              style: TextStyle(color: textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx); // pop dialog
                  Navigator.pop(context); // pop call screen
                },
                child: const Text('Close', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx); // pop dialog
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const PremiumPlansScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.amberPremium,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Buy Premium', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      );
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppTheme.getTextColor(context);
    final textSecondary = AppTheme.getSecondaryTextColor(context);
    final surfaceColor = AppTheme.getSurfaceColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Header stats
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.tealAccent.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.clock, color: AppTheme.tealAccent, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            _getFormattedTime(),
                            style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                      if (!_isPremium) ...[
                        const SizedBox(height: 4),
                        Text(
                          "Daily left: ${((3600 - (_startDailySeconds + _secondsElapsed)).clamp(0, 3600) ~/ 60)}m ${((3600 - (_startDailySeconds + _secondsElapsed)).clamp(0, 3600) % 60)}s",
                          style: TextStyle(color: textSecondary, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            
            // AI Avatar & sound waves
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _waveController,
                    builder: (context, child) {
                      final val = _waveController.value;
                      return Container(
                        width: 130 + (val * 40),
                        height: 130 + (val * 40),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.tealAccent.withOpacity(0.08),
                        ),
                      );
                    },
                  ),
                  AnimatedBuilder(
                    animation: _waveController,
                    builder: (context, child) {
                      final val = _waveController.value;
                      return Container(
                        width: 110 + (val * 20),
                        height: 110 + (val * 20),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.tealAccent.withOpacity(0.12),
                        ),
                      );
                    },
                  ),
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.tealAccent,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))
                      ],
                    ),
                    child: const Icon(LucideIcons.bot, color: Colors.white, size: 48),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _aiName,
              style: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              _aiTitle,
              style: TextStyle(color: textSecondary, fontSize: 14),
            ),
            
            const Spacer(),
            
            // Subtitle Caption Panel
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.getBorderColor(context)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(LucideIcons.text, color: AppTheme.tealAccent, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'AI SPEAKING (CAPTION)',
                        style: TextStyle(color: textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '"$_currentCaption"',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            
            const Spacer(),
            
            // Call control panel
            Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Mute toggle
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isMuted = !_isMuted;
                      });
                    },
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isMuted ? Colors.blue.withOpacity(0.15) : surfaceColor,
                      ),
                      child: Icon(
                        _isMuted ? LucideIcons.micOff : LucideIcons.mic,
                        color: _isMuted ? Colors.blue : textPrimary,
                      ),
                    ),
                  ),
                  
                  // End Call (red phone)
                  GestureDetector(
                    onTap: _endCall,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.coralAction,
                        boxShadow: [
                          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))
                        ],
                      ),
                      child: const Icon(LucideIcons.phoneOff, color: Colors.white, size: 28),
                    ),
                  ),
                  
                  // Next prompt action
                  GestureDetector(
                    onTap: _advancePrompt,
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.tealAccent.withOpacity(0.15),
                      ),
                      child: const Icon(
                        LucideIcons.skipForward,
                        color: AppTheme.tealAccent,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}