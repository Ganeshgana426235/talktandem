import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
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

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  
  // Real-time state subscription properties
  int _streak = 0;
  int _xp = 0;
  bool _isPremium = false;
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  final List<Widget> _tabs = const [
    MatchingScreen(),
    ChatListScreen(),
    LeaderboardScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final auth = context.read<AuthProvider>();
      final uid = auth.uid;
      if (uid != null) {
        // Guaranteed active presence mapping specifically to our 'talktandem' custom database configuration target
        try {
          final firestore = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'talktandem');
          
          // Direct authenticated phone session mapping is required to guarantee correct document lookup by Phone ID
          final phone = FirebaseAuth.instance.currentUser?.phoneNumber ?? auth.userData?['phoneNumber'];
          
          if (phone == null) {
            debugPrint("[SYSTEM PRESENCE WARNING] Phone number not found. Cannot load user document by Phone ID.");
            return;
          }

          final userDocRef = firestore.collection('users').doc(phone);

          // 1. Establish immediate real-time listener to keep UI stats fully reactive and current
          _userSubscription?.cancel();
          _userSubscription = userDocRef.snapshots().listen((snapshot) {
            if (mounted && snapshot.exists) {
              final data = snapshot.data() as Map<String, dynamic>?;
              if (data != null) {
                setState(() {
                  _streak = (data['streak'] as num?)?.toInt() ?? 0;
                  _xp = (data['xp'] as num?)?.toInt() ?? 0;
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
              // Consecutive days online: Increment current streak
              streak += 1;
              if (streak > maxStreak) {
                maxStreak = streak;
              }
              debugPrint("[STREAK ENGINE] Consecutive check passed. Streak incremented to: $streak");
            } else if (difference > 1) {
              // Missed days: Reset streak to 1
              streak = 1;
              if (streak > maxStreak) {
                maxStreak = streak;
              }
              debugPrint("[STREAK ENGINE] Missed days detected. Streak reset to: 1");
            } else if (difference == 0 && streak == 0) {
              // Edge case: User is logging in for first time today but has 0 streak
              streak = 1;
              if (streak > maxStreak) {
                maxStreak = streak;
              }
            }
            // If difference == 0 (already came online today), we keep the current streak values unchanged
          } else {
            // First time login with no prior history: Initialize streak to 1
            streak = 1;
            maxStreak = 1;
            debugPrint("[STREAK ENGINE] Initialized new user streak to 1.");
          }

          // Update Firestore safely under the main custom DB target (supports both merge/set if doc missing)
          final writeData = {
            'isOnline': true,
            'streak': streak,
            'maxStreak': maxStreak,
            'lastOnline': Timestamp.fromDate(now),
          };

          if (userDoc.exists) {
            await userDocRef.update(writeData);
          } else {
            await userDocRef.set(writeData, SetOptions(merge: true));
          }
          
          debugPrint("[SYSTEM PRESENCE & STREAK] Updated successfully on Firestore.");

          // Sync the newly calculated values directly into the current AuthProvider state context
          await auth.loadUserData(uid);

        } catch (e) {
          debugPrint("[SYSTEM PRESENCE WARNING] Presence/Streak update failed: $e");
        }
        
        try {
          context.read<AuthProvider>().firestore.setUserOnline(uid, true);
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  // Safe asset/network helper with user-friendly fallback
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
    
    // Resolve stats from real-time stream state if hydrated; fallback to Provider state
    final currentStreak = _streak > 0 ? _streak.toString() : (auth.userData?['streak']?.toString() ?? '0');
    final currentXp = _xp > 0 ? _xp.toString() : (auth.userData?['xp']?.toString() ?? '0');
    final currentIsPremium = _isPremium || ((auth.userData?['isPremium'] as bool?) ?? false);

    final surfaceColor = AppTheme.getSurfaceColor(context);
    final textPrimary = AppTheme.getTextColor(context);
    final textSecondary = AppTheme.getSecondaryTextColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Fetch details for bottom navigation local avatar integration
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
                // Top-left Dynamic Brand Logo with clean message-circle fallback
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
                _HeaderStatChip(
                  icon: LucideIcons.flame,
                  label: currentStreak,
                  color: AppTheme.amberPremium,
                  surfaceColor: surfaceColor,
                  textColor: textPrimary,
                ),
                const SizedBox(width: 8),
                _HeaderStatChip(
                  icon: LucideIcons.zap,
                  label: '$currentXp XP',
                  color: AppTheme.tealAccent,
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
                    child: const Icon(
                      LucideIcons.crown,
                      size: 14,
                      color: AppTheme.amberPremium,
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
  final IconData icon;
  final String label;
  final Color color;
  final Color surfaceColor;
  final Color textColor;

  const _HeaderStatChip({
    required this.icon,
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
          Icon(icon, color: color, size: 16),
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