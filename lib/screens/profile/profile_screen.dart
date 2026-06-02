import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../theme/app_theme.dart';
import '../../models/auth_provider.dart';
import '../auth/auth_screen.dart';

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
      // Retrieve the authenticated user's phone number
      final phone = FirebaseAuth.instance.currentUser?.phoneNumber ?? auth.userData?['phoneNumber'];
      
      if (phone == null) {
        print("[TalkTandem Profile] Phone number not found. Cannot load user document by Phone ID.");
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
      print("[TalkTandem Profile] Failed to establish real-time listener: $e");
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
                      child: const Icon(
                        LucideIcons.logOut,
                        color: AppTheme.errorRed,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Log Out',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Are you sure you want to log out of TalkTandem? You will need to verify your phone number to sign in again.',
                  style: TextStyle(
                    fontSize: 14,
                    color: textSecondary,
                    height: 1.5,
                  ),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          // Close confirmation dialog box
                          Navigator.pop(ctx);
                          
                          final auth = context.read<AuthProvider>();
                          final uid = auth.uid;
                          final phone = auth.userData?['phoneNumber'] as String? ?? 
                              FirebaseAuth.instance.currentUser?.phoneNumber ?? '';

                          // 1. Mark user presence status as offline in your custom Firestore database targeting 'talktandem' db ID
                          if (phone.isNotEmpty) {
                            try {
                              final firestore = FirebaseFirestore.instanceFor(
                                app: Firebase.app(),
                                databaseId: 'talktandem',
                              );
                              await firestore.collection('users').doc(phone).update({'isOnline': false});
                              print("[TalkTandem Profile] Presence mapped offline cleanly under Phone ID: $phone");
                            } catch (presenceError) {
                              print("[TalkTandem Profile] Presence offline warning: $presenceError");
                            }
                          }

                          if (uid != null) {
                            try {
                              await auth.firestore.setUserOnline(uid, false);
                            } catch (_) {}
                          }

                          // 2. Perform global FirebaseAuth signOut transaction
                          try {
                            await auth.logout();
                          } catch (e) {
                            print("[TalkTandem Profile] Sign-out transaction failed: $e");
                          }

                          // 3. WIPE any static state steps and inputs inside AuthScreen to guarantee a clean redirect
                          AuthScreen.resetStaticCaches();

                          // 4. Escape the persistent tab router using rootNavigator to clear history stack
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Log Out',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
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

    // Group avatars by gender to filter options dynamically
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

    // Filter avatars based on user's gender
    final List<String> filteredAvatars =
        gender.toLowerCase() == 'female' ? femaleAvatars : maleAvatars;

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
                          Text(
                            'Edit Profile',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(ctx),
                            icon: Icon(LucideIcons.x, color: textSecondary, size: 20),
                          )
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Choose Avatar',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: textPrimary,
                            ),
                          ),
                          Text(
                            'Showing $gender avatars',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.tealAccent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      
                      SizedBox(
                        height: 72,
                        child: ListView.builder(
                          shrinkWrap: true,
                          scrollDirection: Axis.horizontal,
                          itemCount: filteredAvatars.length,
                          itemBuilder: (context, index) {
                            final avatarUrl = filteredAvatars[index];
                            final isSelected = currentSelectedAvatar == avatarUrl;
                            return GestureDetector(
                              onTap: () {
                                setDialogState(() {
                                  currentSelectedAvatar = avatarUrl;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.only(right: 12.0),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isSelected ? AppTheme.tealAccent : Colors.transparent,
                                          width: 3.0,
                                        ),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(30),
                                        child: Image.asset(
                                          avatarUrl,
                                          width: 54,
                                          height: 54,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return Container(
                                              color: borderColor,
                                              width: 54,
                                              height: 54,
                                              child: const Icon(LucideIcons.user, size: 24),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Positioned(
                                        bottom: 2,
                                        right: 2,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: const BoxDecoration(
                                            color: AppTheme.tealAccent,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            LucideIcons.check,
                                            color: Colors.white,
                                            size: 10,
                                          ),
                                        ),
                                      )
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      TextField(
                        controller: nameController,
                        style: TextStyle(color: textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Full Name',
                          labelStyle: TextStyle(color: textSecondary),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: borderColor),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: AppTheme.tealAccent),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      TextField(
                        controller: locationController,
                        style: TextStyle(color: textPrimary),
                        decoration: InputDecoration(
                          labelText: 'City, State',
                          labelStyle: TextStyle(color: textSecondary),
                          hintText: 'e.g. Hyderabad, Telangana',
                          hintStyle: TextStyle(color: textSecondary.withOpacity(0.5)),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: borderColor),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: AppTheme.tealAccent),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      ElevatedButton(
                        onPressed: () async {
                          final state = AuthProvider.inferStateFromLocation(
                            locationController.text.trim(),
                          );
                          final cleanPhone = auth.userData?['phoneNumber'] as String? ?? 
                              FirebaseAuth.instance.currentUser?.phoneNumber ?? '';

                          if (cleanPhone.isNotEmpty) {
                            try {
                              final firestore = FirebaseFirestore.instanceFor(
                                app: Firebase.app(),
                                databaseId: 'talktandem',
                              );
                              await firestore.collection('users').doc(cleanPhone).update({
                                'name': nameController.text.trim(),
                                'location': locationController.text.trim(),
                                'state': state ?? '',
                                'avatarUrl': currentSelectedAvatar,
                              });
                              print("[TalkTandem Profile] Saved profile updates directly to 'talktandem' db under Phone ID: $cleanPhone");
                            } catch (e) {
                              print("[TalkTandem Profile] Database write error: $e");
                            }
                          } else {
                            print("[TalkTandem Profile] Warning: Phone number empty, cannot save updates.");
                          }

                          try {
                            await auth.firestore.updateProfile(uid, {
                              'name': nameController.text.trim(),
                              'location': locationController.text.trim(),
                              'state': state ?? '',
                              'avatarUrl': currentSelectedAvatar,
                            });
                          } catch (_) {}

                          await auth.loadUserData(uid);

                          if (ctx.mounted) Navigator.pop(ctx);

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Profile updated successfully!'),
                                backgroundColor: AppTheme.tealAccent,
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.tealAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
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

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final textPrimary = AppTheme.getTextColor(context);
    final textSecondary = AppTheme.getSecondaryTextColor(context);
    final surfaceColor = AppTheme.getSurfaceColor(context);
    final borderColor = AppTheme.getBorderColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Resolve details using local reactive live stream values first, falling back to authProvider values
    final name = _liveData?['name'] as String? ?? authProvider.userData?['name'] as String? ?? 'User';
    final phoneNumber = _liveData?['phoneNumber'] as String? ?? authProvider.userData?['phoneNumber'] as String? ?? '';
    final location = _liveData?['location'] as String? ?? authProvider.userData?['location'] as String? ?? '';
    final gender = _liveData?['gender'] as String? ?? authProvider.userData?['gender'] as String? ?? 'Male';
    final interests = List<String>.from(_liveData?['interests'] ?? authProvider.userData?['interests'] ?? []);
    final avatarUrl = _liveData?['avatarUrl'] as String? ?? authProvider.userData?['avatarUrl'] as String?;

    final xp = (_liveData?['xp'] ?? authProvider.userData?['xp'])?.toString() ?? '0';
    final streak = (_liveData?['streak'] ?? authProvider.userData?['streak'])?.toString() ?? '0';
    final maxStreak = (_liveData?['maxStreak'] ?? authProvider.userData?['maxStreak'])?.toString() ?? '0';
    final totalCalls = (_liveData?['totalCalls'] ?? authProvider.userData?['totalCalls'] ?? authProvider.userData?['conversationsCount'])?.toString() ?? '0';
    final minutesPracticed = (_liveData?['minutesPracticed'] ?? authProvider.userData?['minutesPracticed'])?.toString() ?? '0';
    final avgRating = (_liveData?['avgRating'] ?? authProvider.userData?['avgRating'])?.toString() ?? '5.0';

    final bool isNetworkImage = avatarUrl != null && 
        (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://'));

    final isFemale = gender.toLowerCase() == 'female';

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
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
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppTheme.tealAccent, width: 3),
                              ),
                              child: CircleAvatar(
                                radius: 48,
                                backgroundImage: avatarUrl != null
                                    ? (isNetworkImage 
                                        ? NetworkImage(avatarUrl) 
                                        : AssetImage(avatarUrl) as ImageProvider)
                                    : null,
                                backgroundColor: AppTheme.tealAccent,
                                child: avatarUrl == null
                                    ? Text(
                                        name.isNotEmpty
                                            ? name[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          fontSize: 30,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(7),
                              decoration: const BoxDecoration(
                                color: AppTheme.tealAccent,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                LucideIcons.pencil,
                                size: 14,
                                color: isDark
                                    ? AppTheme.darkBackground
                                    : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        phoneNumber,
                        style: TextStyle(color: textSecondary, fontSize: 15),
                      ),
                      const SizedBox(height: 8),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isFemale ? LucideIcons.album : LucideIcons.activity,
                            size: 15,
                            color: isFemale ? Colors.pinkAccent : Colors.blueAccent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            gender,
                            style: TextStyle(
                              color: textSecondary, 
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (location.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            Container(
                              width: 1.5,
                              height: 12,
                              color: borderColor,
                            ),
                            const SizedBox(width: 12),
                            Icon(LucideIcons.mapPin, size: 14, color: textSecondary),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                location,
                                style: TextStyle(color: textSecondary, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(height: 1),
                      const SizedBox(height: 20),
                      
                      Row(
                        children: [
                          _buildStatInBox(
                            context,
                            LucideIcons.zap,
                            xp,
                            'Total XP',
                            AppTheme.tealAccent,
                          ),
                          const SizedBox(width: 12),
                          _buildStatInBox(
                            context,
                            LucideIcons.star,
                            avgRating,
                            'Avg Rating',
                            Colors.orangeAccent,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildStatInBox(
                            context,
                            LucideIcons.flame,
                            streak,
                            'Streak',
                            AppTheme.amberPremium,
                          ),
                          const SizedBox(width: 12),
                          _buildStatInBox(
                            context,
                            LucideIcons.award,
                            maxStreak,
                            'Max Streak',
                            Colors.redAccent,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildStatInBox(
                            context,
                            LucideIcons.phone,
                            totalCalls,
                            'Total Calls',
                            Colors.blueAccent,
                          ),
                          const SizedBox(width: 12),
                          _buildStatInBox(
                            context,
                            LucideIcons.clock,
                            minutesPracticed,
                            'Min Practices',
                            Colors.deepPurpleAccent,
                          ),
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
            if (interests.isNotEmpty) ...[
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Interests',
                  style: TextStyle(
                    color: textSecondary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: interests
                    .map(
                      (i) => Chip(
                        label: Text(i, style: const TextStyle(fontSize: 12)),
                        backgroundColor:
                            AppTheme.tealAccent.withOpacity(0.1),
                        side: BorderSide(
                          color: AppTheme.tealAccent.withOpacity(0.3),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 28),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Settings',
                style: TextStyle(
                  color: textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildSettingsTile(
              context,
              LucideIcons.user,
              'Account Details',
              () => _showEditProfileDialog(context),
            ),
            _buildSettingsTile(context, LucideIcons.bell, 'Notifications', () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Notification settings coming soon.')),
              );
            }),
            _buildSettingsTile(
                context, LucideIcons.shieldCheck, 'Privacy & Security', () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Privacy settings coming soon.')),
              );
            }),
            _buildSettingsTile(
                context, LucideIcons.helpCircle, 'Help & Support', () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Contact support@talktandem.app for help.'),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildStatInBox(
    BuildContext context,
    IconData icon,
    String value,
    String label,
    Color color, {
    bool fullWidth = false,
  }) {
    final textPrimary = AppTheme.getTextColor(context);
    final textSecondary = AppTheme.getSecondaryTextColor(context);

    final child = Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(color: textSecondary, fontSize: 12),
        ),
      ],
    );

    if (fullWidth) {
      return child;
    }

    return Expanded(child: child);
  }

  Widget _buildSettingsTile(
    BuildContext context,
    IconData icon,
    String title,
    VoidCallback onTap,
  ) {
    final textPrimary = AppTheme.getTextColor(context);
    final textSecondary = AppTheme.getSecondaryTextColor(context);
    final surfaceColor = AppTheme.getSurfaceColor(context);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.getBorderColor(context)),
        ),
        child: Icon(icon, color: textPrimary, size: 20),
      ),
      title: Text(title,
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.w500)),
      trailing:
          Icon(LucideIcons.chevronRight, color: textSecondary, size: 20),
      onTap: onTap,
    );
  }
}