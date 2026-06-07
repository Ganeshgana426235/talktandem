import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';
import '../../models/auth_provider.dart';

class AccountDetailsScreen extends StatefulWidget {
  const AccountDetailsScreen({super.key});

  @override
  State<AccountDetailsScreen> createState() => _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends State<AccountDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _locationController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    final name = auth.userData?['name'] as String? ?? '';
    final location = auth.userData?['location'] as String? ?? '';
    _nameController = TextEditingController(text: name);
    _locationController = TextEditingController(text: location);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final auth = context.read<AuthProvider>();
    final uid = auth.uid;
    final cleanPhone = auth.userData?['phoneNumber'] as String? ?? 
        FirebaseAuth.instance.currentUser?.phoneNumber ?? '';

    try {
      if (cleanPhone.isNotEmpty) {
        final state = AuthProvider.inferStateFromLocation(_locationController.text.trim());
        final firestore = FirebaseFirestore.instanceFor(
          app: Firebase.app(),
          databaseId: 'talktandem',
        );

        await firestore.collection('users').doc(cleanPhone).set({
          'name': _nameController.text.trim(),
          'location': _locationController.text.trim(),
          'state': state ?? '',
        }, SetOptions(merge: true));
      }

      if (uid != null) {
        await auth.loadUserData(uid);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account details updated successfully!'),
            backgroundColor: AppTheme.emeraldGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update details: $e'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  ImageProvider? _getAvatarProvider(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('http')) return NetworkImage(url);
    return AssetImage(url);
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final textPrimary = AppTheme.getTextColor(context);
    final textSecondary = AppTheme.getSecondaryTextColor(context);
    final surfaceColor = AppTheme.getSurfaceColor(context);
    final borderColor = AppTheme.getBorderColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final name = authProvider.userData?['name'] as String? ?? 'User';
    final phoneNumber = authProvider.userData?['phoneNumber'] as String? ?? '';
    final avatarUrl = authProvider.userData?['avatarUrl'] as String?;
    final bool isPremiumUser = authProvider.userData?['isPremium'] as bool? ?? false;
    final createdAt = authProvider.userData?['createdAt'];

    String formattedJoinDate = 'N/A';
    if (createdAt != null) {
      if (createdAt is Timestamp) {
        formattedJoinDate = DateFormat('dd MMM yyyy').format(createdAt.toDate());
      }
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Account Details',
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Avatar Header
                Center(
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
                      if (isPremiumUser)
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppTheme.amberPremium,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            LucideIcons.crown,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Editable Fields Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PROFILE INFORMATION',
                        style: TextStyle(
                          color: textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Name Field
                      TextFormField(
                        controller: _nameController,
                        style: TextStyle(color: textPrimary, fontSize: 15),
                        decoration: InputDecoration(
                          labelText: 'Full Name',
                          labelStyle: TextStyle(color: textSecondary, fontSize: 13),
                          prefixIcon: const Icon(LucideIcons.user, color: AppTheme.tealAccent, size: 20),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: borderColor),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: AppTheme.tealAccent, width: 2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: AppTheme.errorRed),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: AppTheme.errorRed, width: 2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Location Field
                      TextFormField(
                        controller: _locationController,
                        style: TextStyle(color: textPrimary, fontSize: 15),
                        decoration: InputDecoration(
                          labelText: 'City, State',
                          labelStyle: TextStyle(color: textSecondary, fontSize: 13),
                          prefixIcon: const Icon(LucideIcons.mapPin, color: AppTheme.tealAccent, size: 20),
                          hintText: 'e.g. Bangalore, Karnataka',
                          hintStyle: TextStyle(color: textSecondary.withOpacity(0.5)),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(color: borderColor),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: AppTheme.tealAccent, width: 2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: AppTheme.errorRed),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderSide: const BorderSide(color: AppTheme.errorRed, width: 2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your location';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Read Only Account Meta Card
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ACCOUNT METRICS',
                        style: TextStyle(
                          color: textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Phone Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.tealAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(LucideIcons.phone, color: AppTheme.tealAccent, size: 20),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Phone Number', style: TextStyle(color: textSecondary, fontSize: 11)),
                                const SizedBox(height: 2),
                                Text(phoneNumber, style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'VERIFIED',
                              style: TextStyle(color: textSecondary, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 16),

                      // Joined Date Row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppTheme.tealAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(LucideIcons.calendar, color: AppTheme.tealAccent, size: 20),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Member Since', style: TextStyle(color: textSecondary, fontSize: 11)),
                              const SizedBox(height: 2),
                              Text(formattedJoinDate, style: TextStyle(color: textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Save Changes Button
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.tealAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
