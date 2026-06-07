import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../theme/app_theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppTheme.getTextColor(context);
    final textSecondary = AppTheme.getSecondaryTextColor(context);
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
          'About TalkTandem',
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
              const SizedBox(height: 16),
              // App Brand Header
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.tealAccent.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.tealAccent.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        LucideIcons.messageSquare,
                        color: AppTheme.tealAccent,
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'TalkTandem',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.tealAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'v1.4.0-premium',
                        style: TextStyle(
                          color: AppTheme.tealAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Mission Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'OUR MISSION',
                      style: TextStyle(
                        color: textSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'TalkTandem is a premium peer-to-peer educational community designed to help people achieve speaking fluency. We connect language learners around the world for instant, high-quality voice conversations. We believe that regular, active verbal practice is the absolute key to mastering any language.',
                      style: TextStyle(
                        color: textPrimary,
                        fontSize: 13,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Legal / Document List
              Text(
                'LEGAL & COMPLIANCE',
                style: TextStyle(
                  color: textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    _buildLegalTile(
                      context,
                      LucideIcons.fileText,
                      'Terms of Service',
                      'Review rules & platform guidelines',
                      () => _showContentDialog(context, 'Terms of Service', _termsText),
                    ),
                    const Divider(height: 1),
                    _buildLegalTile(
                      context,
                      LucideIcons.shieldAlert,
                      'Privacy Policy',
                      'How we protect and secure your data',
                      () => _showContentDialog(context, 'Privacy Policy', _privacyText),
                    ),
                    const Divider(height: 1),
                    _buildLegalTile(
                      context,
                      LucideIcons.award,
                      'Open Source Licenses',
                      'Credits for libraries and packages used',
                      () {
                        showLicensePage(
                          context: context,
                          applicationName: 'TalkTandem',
                          applicationVersion: 'v1.4.0-premium',
                          applicationIcon: const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: Icon(LucideIcons.messageSquare, color: AppTheme.tealAccent, size: 32),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Center(
                child: Text(
                  '© 2026 TalkTandem Community. All rights reserved.',
                  style: TextStyle(color: textSecondary, fontSize: 11),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegalTile(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
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
      trailing: Icon(LucideIcons.chevronRight, color: textSecondary, size: 16),
      onTap: onTap,
    );
  }

  void _showContentDialog(BuildContext context, String title, String text) {
    final surface = AppTheme.getSurfaceColor(context);
    final textPrimary = AppTheme.getTextColor(context);
    final textSecondary = AppTheme.getSecondaryTextColor(context);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(title, style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Text(
              text,
              style: TextStyle(color: textSecondary, fontSize: 13, height: 1.5),
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.tealAccent),
              child: const Text('Close', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  static const String _termsText = '''
Welcome to TalkTandem. By using our application, you agree to comply with the following terms:
1. Acceptable Use: Users must communicate respectfully. Harassment, hate speech, or inappropriate language will result in immediate ban.
2. Eligibility: You must verify your phone number to participate.
3. Peer Matching: Matches are done based on online availability.
4. VIP Subscriptions: All active premium tiers are governed by subscription terms and auto-renewals.
''';

  static const String _privacyText = '''
Your privacy matters to us. Here is how we manage data:
1. Data Storage: Your profile data (Name, Location, Avatar URL, and Statistics) is securely stored in Google Firebase Firestore.
2. Phone Numbers: We securely use phone numbers for SMS verification. Your phone number is private and never visible to other users.
3. Audio Data: Peer-to-peer calling operates using WebRTC protocols. Conversation audio is direct between peers and is not stored or recorded on our servers.
''';
}
