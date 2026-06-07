import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _matchNotifications = true;
  bool _echoCancellation = true;
  bool _noiseSuppression = false;

  PermissionStatus _micStatus = PermissionStatus.denied;
  PermissionStatus _notificationStatus = PermissionStatus.denied;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final mic = await Permission.microphone.status;
    final notif = await Permission.notification.status;
    if (mounted) {
      setState(() {
        _micStatus = mic;
        _notificationStatus = notif;
      });
    }
  }

  Future<void> _requestMicPermission() async {
    final status = await Permission.microphone.request();
    setState(() {
      _micStatus = status;
    });
  }

  Future<void> _requestNotificationPermission() async {
    final status = await Permission.notification.request();
    setState(() {
      _notificationStatus = status;
    });
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppTheme.getTextColor(context);
    final surfaceColor = AppTheme.getSurfaceColor(context);
    final borderColor = AppTheme.getBorderColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          'Settings',
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Notification Settings Container
              _buildSectionTitle('NOTIFICATION SETTINGS'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    _buildSwitchTile(
                      icon: LucideIcons.bell,
                      title: 'Match Notifications',
                      subtitle: 'Get alerts when a conversation partner matches',
                      value: _matchNotifications,
                      onChanged: (val) {
                        setState(() {
                          _matchNotifications = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Audio Settings Container
              _buildSectionTitle('AUDIO PREFERENCES'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    _buildSwitchTile(
                      icon: LucideIcons.volumeX,
                      title: 'Acoustic Echo Reduction',
                      subtitle: 'Filters sound feedback loops during call',
                      value: _echoCancellation,
                      onChanged: (val) {
                        setState(() {
                          _echoCancellation = val;
                        });
                      },
                    ),
                    const Divider(height: 1),
                    _buildSwitchTile(
                      icon: LucideIcons.mic,
                      title: 'Noise Suppression',
                      subtitle: 'Reduces background ambiance and static noise',
                      value: _noiseSuppression,
                      onChanged: (val) {
                        setState(() {
                          _noiseSuppression = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // System Permissions Container
              _buildSectionTitle('SYSTEM PERMISSIONS'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    _buildPermissionTile(
                      icon: LucideIcons.mic,
                      title: 'Microphone Permission',
                      subtitle: 'Required for active peer-to-peer conversations',
                      isGranted: _micStatus.isGranted,
                      onTap: _micStatus.isGranted ? null : _requestMicPermission,
                    ),
                    const Divider(height: 1),
                    _buildPermissionTile(
                      icon: LucideIcons.bellRing,
                      title: 'Notification Alerts',
                      subtitle: 'Used for incoming calls & chat message updates',
                      isGranted: _notificationStatus.isGranted,
                      onTap: _notificationStatus.isGranted ? null : _requestNotificationPermission,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Reset local configurations button
              OutlinedButton(
                onPressed: () {
                  setState(() {
                    _matchNotifications = true;
                    _echoCancellation = true;
                    _noiseSuppression = false;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Preferences reset to default values!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: borderColor),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  'Reset Settings to Default',
                  style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    final textSecondary = AppTheme.getSecondaryTextColor(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Text(
        title,
        style: TextStyle(
          color: textSecondary,
          fontWeight: FontWeight.bold,
          fontSize: 11,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final textPrimary = AppTheme.getTextColor(context);
    final textSecondary = AppTheme.getSecondaryTextColor(context);

    return SwitchListTile.adaptive(
      secondary: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.tealAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: AppTheme.tealAccent, size: 18),
      ),
      title: Text(title, style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
      subtitle: Text(subtitle, style: TextStyle(color: textSecondary, fontSize: 11)),
      value: value,
      onChanged: onChanged,
      activeColor: AppTheme.tealAccent,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }

  Widget _buildPermissionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isGranted,
    required VoidCallback? onTap,
  }) {
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
      subtitle: Text(subtitle, style: TextStyle(color: textSecondary, fontSize: 11)),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isGranted ? AppTheme.emeraldGreen.withOpacity(0.15) : AppTheme.errorRed.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          isGranted ? 'GRANTED' : 'ACTION REQUIRED',
          style: TextStyle(
            color: isGranted ? AppTheme.emeraldGreen : AppTheme.errorRed,
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }
}
