import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../theme/app_theme.dart';
import '../../models/auth_provider.dart';
import '../auth/auth_screen.dart';
import '../premium/premium_plans_screen.dart';
import 'account_details_screen.dart';
import 'help_support_screen.dart';
import 'about_screen.dart';
import 'settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  StreamSubscription<DocumentSnapshot>? _userSubscription;
  Map<String, dynamic>? _liveData;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupUserSubscription();
    });
  }

  void _setupUserSubscription() {
    final auth = context.read<AuthProvider>();
    try {
      final firestore = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'talktandem',
      );
      final phone = FirebaseAuth.instance.currentUser?.phoneNumber ?? auth.userData?['phoneNumber'];
      
      if (phone == null) {
        return;
      }

      final userDocRef = firestore.collection('users').doc(phone);

      _userSubscription?.cancel();
      _userSubscription = userDocRef.snapshots().listen((snapshot) {
        if (mounted && snapshot.exists) {
          setState(() {
            _liveData = snapshot.data() as Map<String, dynamic>?;
          });
        }
      });
    } catch (e) {
      debugPrint("Failed to establish user stream: $e");
    }
  }

  @override
  void dispose() {
    _userSubscription?.cancel();
    super.dispose();
  }

  void _showLogoutConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        final surface = AppTheme.getSurfaceColor(ctx);
        final textPrimary = AppTheme.getTextColor(ctx);
        final textSecondary = AppTheme.getSecondaryTextColor(ctx);
        final borderColor = AppTheme.getBorderColor(ctx);

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: surface,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.errorRed.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(LucideIcons.logOut, color: AppTheme.errorRed, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text('Log Out', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Are you sure you want to log out of TalkTandem? You will need to verify your phone number to sign in again.',
                  style: TextStyle(fontSize: 14, color: textSecondary, height: 1.5),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: borderColor),
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
                          final auth = context.read<AuthProvider>();
                          final uid = auth.uid;
                          final phone = auth.userData?['phoneNumber'] as String? ?? 
                              FirebaseAuth.instance.currentUser?.phoneNumber ?? '';

                          if (phone.isNotEmpty) {
                            try {
                              final firestore = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'talktandem');
                              await firestore.collection('users').doc(phone).set({'isOnline': false}, SetOptions(merge: true));
                            } catch (_) {}
                          }

                          if (uid != null) {
                            try {
                              await auth.firestore.setUserOnline(uid, false);
                            } catch (_) {}
                          }

                          try {
                            await auth.logout();
                          } catch (_) {}

                          AuthScreen.resetStaticCaches();

                          if (context.mounted) {
                            Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const AuthScreen()),
                              (route) => false,
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.errorRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
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

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return "N/A";
    if (timestamp is Timestamp) {
      return DateFormat('dd MMM yyyy').format(timestamp.toDate());
    }
    return "N/A";
  }

  ImageProvider? _getAvatarProvider(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return NetworkImage(url);
    return AssetImage(url);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    
    // Lazily initialize user real-time stream subscription when phone number resolves
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber ?? authProvider.userData?['phoneNumber'];
    if (phone != null && _userSubscription == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _setupUserSubscription();
      });
    }

    final textPrimary = AppTheme.getTextColor(context);
    final textSecondary = AppTheme.getSecondaryTextColor(context);
    final surfaceColor = AppTheme.getSurfaceColor(context);
    final borderColor = AppTheme.getBorderColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final name = _liveData?['name'] as String? ?? authProvider.userData?['name'] as String? ?? 'User';
    final phoneNumber = _liveData?['phoneNumber'] as String? ?? authProvider.userData?['phoneNumber'] as String? ?? '';
    final location = _liveData?['location'] as String? ?? authProvider.userData?['location'] as String? ?? '';
    final interests = List<String>.from(_liveData?['interests'] ?? authProvider.userData?['interests'] ?? []);
    final avatarUrl = _liveData?['avatarUrl'] as String? ?? authProvider.userData?['avatarUrl'] as String?;
    
    final bool isPremiumUser = _liveData?['isPremium'] as bool? ?? authProvider.userData?['isPremium'] as bool? ?? false;
    final premiumPlan = _liveData?['premiumPlan'] as String? ?? authProvider.userData?['premiumPlan'] as String? ?? '1_month';
    
    String planName = 'Monthly Pack';
    if (premiumPlan == '1_month') {
      planName = '1 Month Pack';
    } else if (premiumPlan == '3_months') {
      planName = '3 Month Pack';
    } else if (premiumPlan == '1_year') {
      planName = '1 Year Pack';
    }

    final premiumPurchasedAt = _liveData?['premiumPurchasedAt'] ?? authProvider.userData?['premiumPurchasedAt'];
    final premiumExpiresAt = _liveData?['premiumExpiresAt'] ?? authProvider.userData?['premiumExpiresAt'];

    final coins = (_liveData?['coins'] ?? authProvider.userData?['coins'])?.toString() ?? '0';
    final streak = (_liveData?['streak'] ?? authProvider.userData?['streak'])?.toString() ?? '0';
    final maxStreak = (_liveData?['maxStreak'] ?? authProvider.userData?['maxStreak'])?.toString() ?? '0';
    final totalCalls = (_liveData?['totalCalls'] ?? authProvider.userData?['totalCalls'])?.toString() ?? '0';
    final avgRating = (_liveData?['avgRating'] ?? authProvider.userData?['avgRating'])?.toString() ?? '5.0';
    final todayStr = "${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}";
    final lastCallDate = _liveData?['lastCallDate'] as String? ?? authProvider.userData?['lastCallDate'] as String?;
    
    String formatSecondsToMinsSecs(int totalSeconds) {
      final minutes = totalSeconds ~/ 60;
      final seconds = totalSeconds % 60;
      return "${minutes}m ${seconds}s";
    }

    final int totalSecondsVal = ((_liveData?['totalTalkSeconds'] ?? authProvider.userData?['totalTalkSeconds'] ?? 0) as num).toInt();
    final String totalTalkText = formatSecondsToMinsSecs(totalSecondsVal);

    final int todayCallsVal = (lastCallDate == todayStr)
        ? ((_liveData?['todayCalls'] ?? authProvider.userData?['todayCalls'] ?? 0) as num).toInt()
        : 0;
    final int todaySecondsVal = (lastCallDate == todayStr)
        ? ((_liveData?['dailyTalkSeconds'] ?? authProvider.userData?['dailyTalkSeconds'] ?? 0) as num).toInt()
        : 0;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isPremiumUser
                      ? [
                          AppTheme.amberPremium.withOpacity(isDark ? 0.25 : 0.4),
                          AppTheme.tealAccent.withOpacity(isDark ? 0.05 : 0.1),
                        ]
                      : [
                          AppTheme.tealAccent.withOpacity(isDark ? 0.15 : 0.25),
                          surfaceColor,
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
              child: Column(
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AccountDetailsScreen()),
                        );
                      },
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isPremiumUser ? AppTheme.amberPremium : AppTheme.tealAccent,
                                width: 3.5,
                              ),
                            ),
                            child: CircleAvatar(
                              radius: 50,
                              backgroundImage: _getAvatarProvider(avatarUrl),
                              backgroundColor: AppTheme.tealAccent,
                              child: (avatarUrl == null || avatarUrl.isEmpty)
                                  ? Text(
                                      name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                                    )
                                  : null,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: isPremiumUser ? AppTheme.amberPremium : AppTheme.tealAccent,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              LucideIcons.pencil,
                              size: 13,
                              color: isDark ? const Color(0xFF0F172A) : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(name, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary)),
                      if (isPremiumUser) ...[
                        const SizedBox(width: 6),
                        const Icon(LucideIcons.crown, color: AppTheme.amberPremium, size: 22),
                      ]
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(phoneNumber, style: TextStyle(color: textSecondary, fontSize: 13)),
                  if (location.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.mapPin, size: 14, color: textSecondary),
                        const SizedBox(width: 4),
                        Text(location, style: TextStyle(color: textSecondary, fontSize: 13)),
                      ],
                    )
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Dashboard & Statistics', style: TextStyle(color: textSecondary, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
                  const SizedBox(height: 10),
                  GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.05,
                    children: [
                      _buildDashboardCard(context, LucideIcons.coins, coins, 'Total Coins', Colors.amber),
                      _buildDashboardCard(context, LucideIcons.flame, streak, 'Streak', AppTheme.amberPremium),
                      _buildDashboardCard(context, LucideIcons.award, maxStreak, 'Max Streak', Colors.redAccent),
                      _buildDashboardCard(context, LucideIcons.phone, totalCalls, 'Calls Made', Colors.blueAccent),
                      _buildDashboardCard(context, LucideIcons.clock, totalTalkText, 'Total Practice', Colors.deepPurpleAccent),
                      _buildDashboardCard(context, LucideIcons.star, avgRating, 'Avg Rating', Colors.orangeAccent),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text("Today's Progress", style: TextStyle(color: textSecondary, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(LucideIcons.phoneCall, color: AppTheme.tealAccent, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  "Today's Calls",
                                  style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            Text(
                              "$todayCallsVal calls",
                              style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(LucideIcons.hourglass, color: AppTheme.tealAccent, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  "Practice Time",
                                  style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            Text(
                              isPremiumUser 
                                  ? "${formatSecondsToMinsSecs(todaySecondsVal)} (Unlimited)" 
                                  : "${formatSecondsToMinsSecs(todaySecondsVal)} / 60m 0s",
                              style: TextStyle(
                                color: todaySecondsVal >= 3600 && !isPremiumUser ? AppTheme.errorRed : textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        if (!isPremiumUser) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: (todaySecondsVal / 3600.0).clamp(0.0, 1.0),
                              backgroundColor: borderColor,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.tealAccent),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text("Practice Calendar", style: TextStyle(color: textSecondary, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
                  const SizedBox(height: 10),
                  PracticeCalendarWidget(phone: phoneNumber, totalCalls: totalCalls),
                  const SizedBox(height: 24),
                  Text('Subscription Management', style: TextStyle(color: textSecondary, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isPremiumUser ? AppTheme.amberPremium.withOpacity(0.5) : borderColor,
                        width: isPremiumUser ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Icon(
                                    isPremiumUser ? LucideIcons.crown : LucideIcons.sparkles,
                                    color: isPremiumUser ? AppTheme.amberPremium : AppTheme.tealAccent,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      isPremiumUser ? 'VIP Premium Active ($planName)' : 'Upgrade to VIP Premium',
                                      style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isPremiumUser ? AppTheme.amberPremium.withOpacity(0.15) : textSecondary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isPremiumUser ? 'PREPAID' : 'FREE',
                                style: TextStyle(
                                  color: isPremiumUser ? AppTheme.amberPremium : textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isPremiumUser
                              ? 'Thank you for supporting us! You have unlocked unlimited talking sheets, full AI corrections, ad-free matching, and direct lounge messaging.'
                              : 'Unlock 100% unlimited talk time, direct post-call messaging, instant AI grammar analysis, and block all advertisement banners.',
                          style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        if (isPremiumUser) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('ACTIVATED ON', style: TextStyle(color: textSecondary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                                  const SizedBox(height: 4),
                                  Text(_formatTimestamp(premiumPurchasedAt), style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('EXPIRES ON', style: TextStyle(color: textSecondary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatTimestamp(premiumExpiresAt),
                                    style: const TextStyle(color: AppTheme.emeraldGreen, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ] else ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Mode: Free Standard Access', style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
                              const Text('₹0', style: TextStyle(color: AppTheme.tealAccent, fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const PremiumPlansScreen()),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.tealAccent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('View Premium Low-Cost Tiers', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                  if (interests.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text('My Interests', style: TextStyle(color: textSecondary, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: interests.map((i) => Chip(
                        label: Text(i, style: const TextStyle(fontSize: 12)),
                        backgroundColor: AppTheme.tealAccent.withOpacity(0.08),
                        side: BorderSide(color: AppTheme.tealAccent.withOpacity(0.15)),
                      )).toList(),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Text('App Settings & Options', style: TextStyle(color: textSecondary, fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5)),
                  const SizedBox(height: 10),
                  _buildSettingsContainer(
                    context,
                    [
                      _buildSettingsTile(context, LucideIcons.user, 'Account Details', 'Edit profile name & city', () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AccountDetailsScreen()),
                        );
                      }),
                      const Divider(height: 1),
                      _buildSettingsTile(context, LucideIcons.settings, 'Settings', 'Manage app settings & themes', () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SettingsScreen()),
                        );
                      }),
                      const Divider(height: 1),
                      _buildSettingsTile(context, LucideIcons.helpCircle, 'Help Desk & Support', 'Reach out for help & issues', () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const HelpSupportScreen()),
                        );
                      }),
                      const Divider(height: 1),
                      _buildSettingsTile(context, LucideIcons.info, 'About TalkTandem', 'App version, terms, licensing', () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AboutScreen()),
                        );
                      }),
                      const Divider(height: 1),
                      _buildSettingsTile(
                        context,
                        LucideIcons.logOut,
                        'Log Out',
                        'Sign out of your account',
                        () => _showLogoutConfirmDialog(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardCard(BuildContext context, IconData icon, String value, String label, Color color) {
    final textPrimary = AppTheme.getTextColor(context);
    final textSecondary = AppTheme.getSecondaryTextColor(context);
    final surfaceColor = AppTheme.getSurfaceColor(context);
    final borderColor = AppTheme.getBorderColor(context);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          FittedBox(
            child: Text(
              value,
              style: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecondary, fontSize: 9, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsContainer(BuildContext context, List<Widget> children) {
    final surfaceColor = AppTheme.getSurfaceColor(context);
    final borderColor = AppTheme.getBorderColor(context);

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSettingsTile(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap) {
    final textPrimary = AppTheme.getTextColor(context);
    final textSecondary = AppTheme.getSecondaryTextColor(context);

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.tealAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppTheme.tealAccent, size: 18),
      ),
      title: Text(title, style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(subtitle, style: TextStyle(color: textSecondary, fontSize: 12)),
      trailing: Icon(LucideIcons.chevronRight, color: textSecondary, size: 18),
      onTap: onTap,
    );
  }
}

class PracticeCalendarWidget extends StatefulWidget {
  final String phone;
  final String totalCalls;

  const PracticeCalendarWidget({super.key, required this.phone, required this.totalCalls});

  @override
  State<PracticeCalendarWidget> createState() => _PracticeCalendarWidgetState();
}

class _PracticeCalendarWidgetState extends State<PracticeCalendarWidget> {
  DateTime _selectedMonth = DateTime.now();
  Map<String, int> _localHistory = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMonthData(_selectedMonth);
  }

  @override
  void didUpdateWidget(PracticeCalendarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phone != widget.phone || oldWidget.totalCalls != widget.totalCalls) {
      _loadMonthData(_selectedMonth);
    }
  }

  Future<void> _loadMonthData(DateTime month) async {
    if (widget.phone.isEmpty) return;
    
    final firstDayStr = "${month.year}-${month.month.toString().padLeft(2, '0')}-01";
    final lastDayStr = "${month.year}-${month.month.toString().padLeft(2, '0')}-${DateTime(month.year, month.month + 1, 0).day.toString().padLeft(2, '0')}";

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final firestore = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'talktandem',
      );
      final querySnapshot = await firestore
          .collection('users')
          .doc(widget.phone)
          .collection('practice_history')
          .where('date', isGreaterThanOrEqualTo: firstDayStr)
          .where('date', isLessThanOrEqualTo: lastDayStr)
          .get();

      final Map<String, int> monthData = {};
      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final dateStr = doc.id;
        final seconds = (data['seconds'] as num?)?.toInt() ?? ((data['minutes'] as num?)?.toInt() ?? 0) * 60;
        monthData[dateStr] = seconds;
      }

      debugPrint("Loaded calendar month data for $firstDayStr to $lastDayStr: ${monthData.length} records found.");

      if (mounted) {
        setState(() {
          _localHistory = monthData;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading calendar month data: $e");
      if (mounted) {
        setState(() {
          _localHistory = {};
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppTheme.getTextColor(context);
    final surfaceColor = AppTheme.getSurfaceColor(context);
    final borderColor = AppTheme.getBorderColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Month Calculations
    final firstDay = DateTime(_selectedMonth.year, _selectedMonth.month, 1);
    final lastDay = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final daysInMonth = lastDay.day;
    
    // Weekday of the first day (Monday = 1, Sunday = 7)
    final offset = firstDay.weekday - 1;

    final monthName = DateFormat('MMMM yyyy').format(_selectedMonth);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(LucideIcons.chevronLeft, color: textPrimary, size: 20),
                onPressed: () {
                  setState(() {
                    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
                  });
                  _loadMonthData(_selectedMonth);
                },
              ),
              Text(
                monthName,
                style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              IconButton(
                icon: Icon(LucideIcons.chevronRight, color: textPrimary, size: 20),
                onPressed: () {
                  setState(() {
                    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
                  });
                  _loadMonthData(_selectedMonth);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Weekday Headers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const [
              _DayHeader(label: 'M'),
              _DayHeader(label: 'T'),
              _DayHeader(label: 'W'),
              _DayHeader(label: 'T'),
              _DayHeader(label: 'F'),
              _DayHeader(label: 'S'),
              _DayHeader(label: 'S'),
            ],
          ),
          const SizedBox(height: 8),
          
          // Days Grid / Loading
          _isLoading
              ? const SizedBox(
                  height: 200,
                  child: Center(
                    child: CircularProgressIndicator(color: AppTheme.tealAccent),
                  ),
                )
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: offset + daysInMonth,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                  ),
                  itemBuilder: (context, index) {
                    if (index < offset) {
                      return const SizedBox.shrink();
                    }

                    final day = index - offset + 1;
                    final dateStr = "${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}";
                    final seconds = _localHistory[dateStr] ?? 0;

                    final today = DateTime.now();
                    final isToday = today.year == _selectedMonth.year &&
                        today.month == _selectedMonth.month &&
                        today.day == day;

                    Color? highlightColor;
                    Color textColor = textPrimary;
                    BoxBorder? cellBorder;

                    if (seconds > 0) {
                      textColor = Colors.white;
                      if (seconds < 900) {
                        highlightColor = Colors.green.withOpacity(0.4);
                      } else if (seconds < 1800) {
                        highlightColor = Colors.green.withOpacity(0.7);
                      } else {
                        highlightColor = Colors.green;
                      }
                    }

                    if (isToday) {
                      cellBorder = Border.all(color: Colors.blueAccent, width: 2.2);
                      if (seconds == 0) {
                        highlightColor = Colors.blueAccent.withOpacity(0.15);
                        textColor = isDark ? Colors.blueAccent : Colors.blue.shade800;
                      }
                    } else if (highlightColor == null) {
                      cellBorder = Border.all(color: borderColor.withOpacity(0.5), width: 0.5);
                    }

                    final String tooltipMessage = seconds > 0 
                        ? "${seconds ~/ 60}m ${seconds % 60}s practiced" 
                        : "No practice";

                    return Tooltip(
                      message: tooltipMessage,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: highlightColor,
                          border: cellBorder,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          "$day",
                          style: TextStyle(
                            color: textColor,
                            fontWeight: seconds > 0 || isToday ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  },
                ),
          const SizedBox(height: 16),
          
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendItem(color: Colors.transparent, border: borderColor, label: '0s'),
              const SizedBox(width: 8),
              _LegendItem(color: Colors.green.withOpacity(0.4), label: '1s-15m'),
              const SizedBox(width: 8),
              _LegendItem(color: Colors.green.withOpacity(0.7), label: '15-30m'),
              const SizedBox(width: 8),
              _LegendItem(color: Colors.green, label: '30m+'),
              const SizedBox(width: 8),
              _LegendItem(
                color: Colors.blueAccent.withOpacity(0.15),
                border: Colors.blueAccent,
                label: 'Today',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  final String label;

  const _DayHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppTheme.getSecondaryTextColor(context),
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final Color? border;
  final String label;

  const _LegendItem({required this.color, this.border, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: border != null ? Border.all(color: border!) : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: AppTheme.getSecondaryTextColor(context),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}