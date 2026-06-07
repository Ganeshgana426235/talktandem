import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:lottie/lottie.dart'; // Imported Lottie package

import '../../models/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../matching/matching_screen.dart';
import '../chat/chat_list_screen.dart';
import '../leaderboard/leaderboard_screen.dart';
import '../profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

// Added WidgetsBindingObserver to detect when app opens/closes
class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  
  int _streak = 0;
  int _coins = 0;
  bool _isPremium = false;
  
  StreamSubscription<DocumentSnapshot>? _userSubscription;
  Timer? _presenceTimer; // Timer for 5-minute heartbeat

  final List<Widget> _tabs = const [
    MatchingScreen(),
    ChatListScreen(),
    LeaderboardScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Listen to app lifecycle
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _setupUserStreamAndStreak();
      _startPresenceHeartbeat();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _userSubscription?.cancel();
    _presenceTimer?.cancel();
    _setOnlineStatus(false); // Instantly offline when widget is destroyed
    super.dispose();
  }

  // Detects if user minimizes the app, closes it, or opens it back up
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _setOnlineStatus(true);
      _startPresenceHeartbeat();
    } else if (state == AppLifecycleState.paused || 
               state == AppLifecycleState.detached || 
               state == AppLifecycleState.inactive) {
      _setOnlineStatus(false);
      _presenceTimer?.cancel();
    }
  }

  void _startPresenceHeartbeat() {
    _presenceTimer?.cancel();
    _setOnlineStatus(true);
    // Ping Firestore every 3 minutes to confirm user is actively looking at the screen
    _presenceTimer = Timer.periodic(const Duration(minutes: 3), (_) {
      _setOnlineStatus(true);
    });
  }

  Future<void> _setOnlineStatus(bool isOnline) async {
    try {
      final auth = context.read<AuthProvider>();
      final uid = auth.uid;
      final phone = FirebaseAuth.instance.currentUser?.phoneNumber ?? auth.userData?['phoneNumber'];
      
      if (phone != null) {
        final firestore = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'talktandem');
        await firestore.collection('users').doc(phone).set({
          'isOnline': isOnline,
          'lastActive': FieldValue.serverTimestamp(), // Crucial for our Cloud Function
        }, SetOptions(merge: true));
      }
      
      if (uid != null && isOnline) {
         auth.firestore.setUserOnline(uid, isOnline);
      }
    } catch (e) {
      debugPrint("[PRESENCE ENGINE] Failed to update presence: $e");
    }
  }

  Future<void> _setupUserStreamAndStreak() async {
    final auth = context.read<AuthProvider>();
    final uid = auth.uid;
    if (uid != null) {
      try {
        final firestore = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'talktandem');
        final phone = FirebaseAuth.instance.currentUser?.phoneNumber ?? auth.userData?['phoneNumber'];
        
        if (phone == null) return;

        final userDocRef = firestore.collection('users').doc(phone);

        _userSubscription?.cancel();
        _userSubscription = userDocRef.snapshots().listen((snapshot) {
          if (mounted && snapshot.exists) {
            final data = snapshot.data() as Map<String, dynamic>?;
            if (data != null) {
              setState(() {
                _streak = (data['streak'] as num?)?.toInt() ?? 0;
                _coins = (data['coins'] as num?)?.toInt() ?? 0;
                _isPremium = (data['isPremium'] as bool?) ?? false;
              });
            }
          }
        });

        final userDoc = await userDocRef.get();
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        int streak = 0;
        int maxStreak = 0;
        Timestamp? lastOnlineTimestamp;

        if (userDoc.exists) {
          final data = userDoc.data();
          if (data != null) {
            streak = (data['streak'] as num?)?.toInt() ?? 0;
            maxStreak = (data['maxStreak'] as num?)?.toInt() ?? 0;
            lastOnlineTimestamp = data['lastOnline'] as Timestamp?;
          }
        }

        if (lastOnlineTimestamp != null) {
          final lastOnlineDate = lastOnlineTimestamp.toDate();
          final lastDate = DateTime(lastOnlineDate.year, lastOnlineDate.month, lastOnlineDate.day);
          final difference = today.difference(lastDate).inDays;

          if (difference == 1) {
            streak += 1;
            if (streak > maxStreak) maxStreak = streak;
          } else if (difference > 1) {
            streak = 1;
            if (streak > maxStreak) maxStreak = streak;
          } else if (difference == 0 && streak == 0) {
            streak = 1;
            if (streak > maxStreak) maxStreak = streak;
          }
        } else {
          streak = 1;
          maxStreak = 1;
        }

        await userDocRef.set({
          'streak': streak,
          'maxStreak': maxStreak,
          'lastOnline': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await auth.loadUserData(uid);

      } catch (e) {
        debugPrint("[SYSTEM PRESENCE WARNING] Update failed: $e");
      }
    }
  }

  Widget _buildFallbackInitial(String name, Color textColor) {
    return Container(
      color: AppTheme.tealAccent,
      alignment: Alignment.center,
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'U',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    
    final currentStreak = _streak > 0 ? _streak.toString() : (auth.userData?['streak']?.toString() ?? '0');
    final currentCoins = _coins > 0 ? _coins.toString() : (auth.userData?['coins']?.toString() ?? '0');
    final currentIsPremium = _isPremium || ((auth.userData?['isPremium'] as bool?) ?? false);

    final surfaceColor = AppTheme.getSurfaceColor(context);
    final textPrimary = AppTheme.getTextColor(context);
    final textSecondary = AppTheme.getSecondaryTextColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final avatarUrl = auth.appUser?.avatarUrl;
    final userName = auth.appUser?.name ?? 'U';

    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.of(context).padding.top + 12,
              20,
              16,
            ),
            decoration: BoxDecoration(
              color: surfaceColor,
              border: Border(
                bottom: BorderSide(color: AppTheme.getBorderColor(context)),
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    'lib/assets/logo/tt_logo.png',
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.tealAccent.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          LucideIcons.messageCircle,
                          color: AppTheme.tealAccent,
                          size: 20,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'TalkTandem',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: textPrimary,
                  ),
                ),
                const Spacer(),
                // Updated Streak Chip
                _HeaderStatChip(
                  lottiePath: 'lib/assets/animations/streak.json',
                  label: currentStreak,
                  color: AppTheme.amberPremium,
                  surfaceColor: surfaceColor,
                  textColor: textPrimary,
                ),
                const SizedBox(width: 8),
                // Updated Coin Chip
                _HeaderStatChip(
                  lottiePath: 'lib/assets/animations/coin.json',
                  label: '$currentCoins ',
                  color: Colors.amber,
                  surfaceColor: surfaceColor,
                  textColor: textPrimary,
                ),
                if (currentIsPremium) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.amberPremium.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AppTheme.amberPremium.withOpacity(0.5),
                      ),
                    ),
                    // Updated Premium Crown icon
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: Lottie.asset(
                        'lib/assets/animations/premium2.json',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(LucideIcons.crown, size: 14, color: AppTheme.amberPremium),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _tabs,
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black26
                  : Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          backgroundColor: surfaceColor,
          selectedItemColor: AppTheme.tealAccent,
          unselectedItemColor: textSecondary,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          onTap: (index) => setState(() => _currentIndex = index),
          items: [
            BottomNavigationBarItem(
              icon: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _currentIndex == 0 ? AppTheme.tealAccent : textSecondary.withOpacity(0.4),
                    width: 1.8,
                  ),
                ),
                child: ClipOval(
                  child: avatarUrl != null && avatarUrl.isNotEmpty
                      ? (avatarUrl.startsWith('http')
                          ? Image.network(
                              avatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildFallbackInitial(userName, Colors.white),
                            )
                          : Image.asset(
                              avatarUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildFallbackInitial(userName, Colors.white),
                            ))
                      : _buildFallbackInitial(userName, Colors.white),
                ),
              ),
              label: 'Call',
            ),
            const BottomNavigationBarItem(
              icon: Icon(LucideIcons.messageSquare),
              label: 'Lounge',
            ),
            const BottomNavigationBarItem(
              icon: Icon(LucideIcons.trophy),
              label: 'Leaderboard',
            ),
            const BottomNavigationBarItem(
              icon: Icon(LucideIcons.user),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderStatChip extends StatelessWidget {
  final String lottiePath;
  final String label;
  final Color color;
  final Color surfaceColor;
  final Color textColor;

  const _HeaderStatChip({
    required this.lottiePath,
    required this.label,
    required this.color,
    required this.surfaceColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Render Lottie here
          SizedBox(
            width: 18,
            height: 18,
            child: Lottie.asset(
              lottiePath,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => Icon(Icons.error, color: color, size: 16),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: textColor,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}