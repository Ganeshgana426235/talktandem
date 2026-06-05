import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Run 'flutter pub add intl' for date formatting
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../theme/app_theme.dart';
import '../../models/auth_provider.dart';
import '../auth/auth_screen.dart';
import '../../services/iap_service.dart';

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
                              await firestore.collection('users').doc(phone).update({'isOnline': false});
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

  void _showEditProfileDialog(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final uid = auth.uid;
    if (uid == null) return;

    final nameController = TextEditingController(
        text: _liveData?['name'] as String? ?? auth.userData?['name'] as String? ?? '');
    final locationController = TextEditingController(
        text: _liveData?['location'] as String? ?? auth.userData?['location'] as String? ?? '');

    String currentSelectedAvatar = _liveData?['avatarUrl'] as String? ?? auth.userData?['avatarUrl'] as String? ?? '';
    final String gender = _liveData?['gender'] as String? ?? auth.userData?['gender'] as String? ?? 'Male';

    final List<String> maleAvatars = [
      'lib/assets/avatar/male/male1.png',
      'lib/assets/avatar/male/male2.png',
      'lib/assets/avatar/male/male3.png',
      'lib/assets/avatar/male/male4.png',
    ];

    final List<String> femaleAvatars = [
      'lib/assets/avatar/female/female1.png',
      'lib/assets/avatar/female/female2.png',
      'lib/assets/avatar/female/female3.png',
      'lib/assets/avatar/female/female4.png',
    ];

    final List<String> filteredAvatars = gender.toLowerCase() == 'female' ? femaleAvatars : maleAvatars;

    if (currentSelectedAvatar.isEmpty || !filteredAvatars.contains(currentSelectedAvatar)) {
      currentSelectedAvatar = filteredAvatars.first;
    }

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
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Edit Profile', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary)),
                          IconButton(onPressed: () => Navigator.pop(ctx), icon: Icon(LucideIcons.x, color: textSecondary, size: 20))
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameController,
                        style: TextStyle(color: textPrimary),
                        decoration: InputDecoration(labelText: 'Full Name', labelStyle: TextStyle(color: textSecondary)),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: locationController,
                        style: TextStyle(color: textPrimary),
                        decoration: InputDecoration(labelText: 'City, State', labelStyle: TextStyle(color: textSecondary)),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () async {
                          final state = AuthProvider.inferStateFromLocation(locationController.text.trim());
                          final cleanPhone = auth.userData?['phoneNumber'] as String? ?? FirebaseAuth.instance.currentUser?.phoneNumber ?? '';

                          if (cleanPhone.isNotEmpty) {
                            try {
                              final firestore = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'talktandem');
                              await firestore.collection('users').doc(cleanPhone).update({
                                'name': nameController.text.trim(),
                                'location': locationController.text.trim(),
                                'state': state ?? '',
                              });
                            } catch (_) {}
                          }
                          await auth.loadUserData(uid);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.tealAccent),
                        child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _showSubscriptionPlansDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        final iapService = context.watch<InAppPurchaseService>();
        final textPrimary = AppTheme.getTextColor(context);
        final surface = AppTheme.getSurfaceColor(context);

        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: surface,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Select Premium Plan', style: TextStyle(color: textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildPlanTile(context, '1 Month Pack', '₹99 upfront cost', () {
                  Navigator.pop(ctx);
                  iapService.buyPremium();
                }),
                const SizedBox(height: 10),
                _buildPlanTile(context, '3 Month Pack', '₹249 upfront cost', () {
                  Navigator.pop(ctx);
                  iapService.buyPremium(); 
                }),
                const SizedBox(height: 10),
                _buildPlanTile(context, '1 Year Pack', '₹799 upfront cost', () {
                  Navigator.pop(ctx);
                  iapService.buyPremium();
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlanTile(BuildContext context, String title, String price, VoidCallback onTap) {
    return ListTile(
      tileColor: AppTheme.getBorderColor(context).withOpacity(0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(title, style: TextStyle(color: AppTheme.getTextColor(context), fontWeight: FontWeight.bold)),
      subtitle: Text(price, style: const TextStyle(color: AppTheme.tealAccent, fontWeight: FontWeight.w500)),
      trailing: const Icon(LucideIcons.chevronRight, color: AppTheme.tealAccent),
      onTap: onTap,
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return "N/A";
    if (timestamp is Timestamp) {
      return DateFormat('dd MMM yyyy').format(timestamp.toDate());
    }
    return "N/A";
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final textPrimary = AppTheme.getTextColor(context);
    final textSecondary = AppTheme.getSecondaryTextColor(context);
    final surfaceColor = AppTheme.getSurfaceColor(context);
    final borderColor = AppTheme.getBorderColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final name = _liveData?['name'] as String? ?? authProvider.userData?['name'] as String? ?? 'User';
    final phoneNumber = _liveData?['phoneNumber'] as String? ?? authProvider.userData?['phoneNumber'] as String? ?? '';
    final location = _liveData?['location'] as String? ?? authProvider.userData?['location'] as String? ?? '';
    final gender = _liveData?['gender'] as String? ?? authProvider.userData?['gender'] as String? ?? 'Male';
    final interests = List<String>.from(_liveData?['interests'] ?? authProvider.userData?['interests'] ?? []);
    final avatarUrl = _liveData?['avatarUrl'] as String? ?? authProvider.userData?['avatarUrl'] as String?;
    
    // Core Dynamic Premium and Lifecycles fields from database maps
    final bool isPremiumUser = _liveData?['isPremium'] as bool? ?? authProvider.userData?['isPremium'] as bool? ?? false;
    final premiumPurchasedAt = _liveData?['premiumPurchasedAt'] ?? authProvider.userData?['premiumPurchasedAt'];
    final premiumExpiresAt = _liveData?['premiumExpiresAt'] ?? authProvider.userData?['premiumExpiresAt'];

    final xp = (_liveData?['xp'] ?? authProvider.userData?['xp'])?.toString() ?? '0';
    final streak = (_liveData?['streak'] ?? authProvider.userData?['streak'])?.toString() ?? '0';
    final maxStreak = (_liveData?['maxStreak'] ?? authProvider.userData?['maxStreak'])?.toString() ?? '0';
    final totalCalls = (_liveData?['totalCalls'] ?? authProvider.userData?['totalCalls'])?.toString() ?? '0';
    final minutesPracticed = (_liveData?['minutesPracticed'] ?? authProvider.userData?['minutesPracticed'])?.toString() ?? '0';
    final avgRating = (_liveData?['avgRating'] ?? authProvider.userData?['avgRating'])?.toString() ?? '5.0';

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // PROFILE IDENTIFICATION CONTAINER (Glassmorphic modern adjustments)
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(isDark ? 0.25 : 0.05), blurRadius: 16, offset: const Offset(0, 8))
                    ]
                  ),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () => _showEditProfileDialog(context),
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: isPremiumUser ? AppTheme.amberPremium : AppTheme.tealAccent, width: 3)),
                              child: CircleAvatar(
                                radius: 48,
                                backgroundImage: avatarUrl != null ? AssetImage(avatarUrl) : null,
                                backgroundColor: AppTheme.tealAccent,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(color: isPremiumUser ? AppTheme.amberPremium : AppTheme.tealAccent, shape: BoxShape.circle),
                              child: Icon(LucideIcons.pencil, size: 14, color: isDark ? AppTheme.darkBackground : Colors.white),
                            ),
                          ],
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
                      Text(phoneNumber, style: TextStyle(color: textSecondary, fontSize: 14)),
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
                      const SizedBox(height: 20),
                      const Divider(height: 1),
                      const SizedBox(height: 20),
                      
                      // Stat Display Blocks Grid
                      Row(
                        children: [
                          _buildStatInBox(context, LucideIcons.zap, xp, 'Total XP', AppTheme.tealAccent),
                          const SizedBox(width: 12),
                          _buildStatInBox(context, LucideIcons.star, avgRating, 'Avg Rating', Colors.orangeAccent),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildStatInBox(context, LucideIcons.flame, streak, 'Streak', AppTheme.amberPremium),
                          const SizedBox(width: 12),
                          _buildStatInBox(context, LucideIcons.award, maxStreak, 'Max Streak', Colors.redAccent),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildStatInBox(context, LucideIcons.phone, totalCalls, 'Total Calls', Colors.blueAccent),
                          const SizedBox(width: 12),
                          _buildStatInBox(context, LucideIcons.clock, minutesPracticed, 'Min Practiced', Colors.deepPurpleAccent),
                        ],
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(LucideIcons.logOut, color: AppTheme.errorRed),
                    onPressed: () => _showLogoutConfirmDialog(context),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),

            // 👑 PREMIUM STATUS CONSOLE PANEL (High-fidelity design update)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: isPremiumUser 
                    ? [AppTheme.amberPremium.withOpacity(0.18), surfaceColor.withOpacity(0.6)]
                    : [AppTheme.tealAccent.withOpacity(0.12), surfaceColor.withOpacity(0.6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(color: isPremiumUser ? AppTheme.amberPremium.withOpacity(0.6) : borderColor, width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(isPremiumUser ? LucideIcons.crown : LucideIcons.sparkles, 
                               color: isPremiumUser ? AppTheme.amberPremium : AppTheme.tealAccent, size: 26),
                          const SizedBox(width: 12),
                          Text(
                            isPremiumUser ? 'Premium Active' : 'Upgrade to Premium Pack',
                            style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 17),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isPremiumUser ? AppTheme.amberPremium.withOpacity(0.2) : Colors.grey.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isPremiumUser ? 'PREPAID' : 'FREE MODE',
                          style: TextStyle(
                            color: isPremiumUser ? AppTheme.amberPremium : textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isPremiumUser 
                      ? 'Awesome! You have unlimited peer matchmaking connection limits, zero advertisement banners, and direct access to gaming modules.'
                      : 'Unlock 100% unlimited talk time sheets, completely ad-free matching sequences, and real-time interactive training games.',
                    style: TextStyle(color: textSecondary, fontSize: 13, height: 1.4),
                  ),
                  
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),

                  // 📅 SUBSCRIPTION METRICS TRACKER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('START DATE', style: TextStyle(color: textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                          const SizedBox(height: 4),
                          Text(isPremiumUser ? _formatTimestamp(premiumPurchasedAt) : 'N/A', 
                               style: TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('VALID UNTIL', style: TextStyle(color: textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                          const SizedBox(height: 4),
                          Text(isPremiumUser ? _formatTimestamp(premiumExpiresAt) : 'N/A', 
                               style: TextStyle(color: isPremiumUser ? AppTheme.emeraldGreen : textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      )
                    ],
                  ),

                  if (!isPremiumUser) ...[
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => _showSubscriptionPlansDialog(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.tealAccent, 
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))
                        ),
                        child: const Text('View Low-Cost Tiers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    )
                  ]
                ],
              ),
            ),

            if (interests.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text('Interests', style: TextStyle(color: textSecondary, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: interests.map((i) => Chip(
                  label: Text(i, style: const TextStyle(fontSize: 12)),
                  backgroundColor: AppTheme.tealAccent.withOpacity(0.1),
                  side: BorderSide(color: AppTheme.tealAccent.withOpacity(0.2)),
                )).toList(),
              ),
            ],
            
            const SizedBox(height: 24),
            Text('Settings', style: TextStyle(color: textSecondary, fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            _buildSettingsTile(context, LucideIcons.user, 'Account Details', () => _showEditProfileDialog(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildStatInBox(BuildContext context, IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.getBorderColor(context).withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.getBorderColor(context).withOpacity(0.1))
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(color: AppTheme.getTextColor(context), fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label, textAlign: TextAlign.center, style: TextStyle(color: AppTheme.getSecondaryTextColor(context), fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile(BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: AppTheme.getSurfaceColor(context), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: AppTheme.getTextColor(context), size: 20),
      ),
      title: Text(title, style: TextStyle(color: AppTheme.getTextColor(context), fontWeight: FontWeight.w500)),
      trailing: Icon(LucideIcons.chevronRight, color: AppTheme.getSecondaryTextColor(context), size: 20),
      onTap: onTap,
    );
  }
}