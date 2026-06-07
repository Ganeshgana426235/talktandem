import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/iap_service.dart';

class PremiumPlansScreen extends StatefulWidget {
  const PremiumPlansScreen({super.key});

  @override
  State<PremiumPlansScreen> createState() => _PremiumPlansScreenState();
}

class _PremiumPlansScreenState extends State<PremiumPlansScreen> {
  String _selectedPlanId = '3_months'; 

  final List<Map<String, dynamic>> _plans = [
    {
      'id': '1_month',
      'title': '1 Month Pack',
      'price': '₹99',
      'period': 'month',
      'saving': 'Standard access',
      'isPopular': false,
    },
    {
      'id': '3_months',
      'title': '3 Month Pack',
      'price': '₹249',
      'period': '3 months',
      'saving': 'Save 16% • Best Value',
      'isPopular': true,
    },
    {
      'id': '1_year',
      'title': '1 Year Pack',
      'price': '₹799',
      'period': 'year',
      'saving': 'Save 33% • Super Saver',
      'isPopular': false,
    },
  ];

  final List<Map<String, dynamic>> _benefits = [
    {
      'icon': LucideIcons.phoneCall,
      'title': 'Unlimited Call Practice',
      'subtitle': 'Talk directly with practice peers without a 90-minute daily limit.',
    },
    {
      'icon': LucideIcons.sparkles,
      'title': 'AI Practice & Corrections',
      'subtitle': 'Get real-time pronunciation and grammar feedback powered by AI.',
    },
    {
      'icon': LucideIcons.award,
      'title': 'Interview Prep Lounge',
      'subtitle': 'Mock interview scenarios and customized learning modules.',
    },
    {
      'icon': LucideIcons.messageSquare,
      'title': 'Direct Messaging after Calls',
      'subtitle': 'Message any caller directly without needing pending friend approval.',
    },
    {
      'icon': LucideIcons.shieldCheck,
      'title': 'Premium Support & Help',
      'subtitle': 'Enjoy priority escalation routes for safety and app improvements.',
    },
    {
      'icon': LucideIcons.ban,
      'title': 'Zero Advertisement Banners',
      'subtitle': 'Enjoy a completely clean interface with no external ads or popups.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppTheme.getTextColor(context);
    final textSecondary = AppTheme.getSecondaryTextColor(context);
    final surfaceColor = AppTheme.getSurfaceColor(context);
    final borderColor = AppTheme.getBorderColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iapService = context.watch<InAppPurchaseService>();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('TalkTandem Premium',
            style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: surfaceColor,
        elevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.tealAccent.withOpacity(0.85),
                    AppTheme.amberPremium.withOpacity(0.85),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(LucideIcons.crown, color: Colors.white, size: 36),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Upgrade to Premium VIP',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Unlock maximum speech capacity, AI learning features, and direct lounge messaging.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select a Subscription Plan',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Column(
                    children: _plans.map((plan) {
                      final isSelected = _selectedPlanId == plan['id'];
                      final isPopular = plan['isPopular'];

                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedPlanId = plan['id'];
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.amberPremium
                                  : (isPopular ? AppTheme.tealAccent.withOpacity(0.3) : borderColor),
                              width: isSelected ? 2.5 : 1,
                            ),
                            boxShadow: [
                              if (isSelected)
                                BoxShadow(
                                  color: AppTheme.amberPremium.withOpacity(0.12),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                )
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? AppTheme.amberPremium : textSecondary.withOpacity(0.4),
                                    width: 2,
                                  ),
                                ),
                                child: isSelected
                                    ? const Center(
                                        child: CircleAvatar(
                                          radius: 5,
                                          backgroundColor: AppTheme.amberPremium,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          plan['title'],
                                          style: TextStyle(
                                            color: textPrimary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                        if (isPopular) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: AppTheme.tealAccent.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: const Text(
                                              'BEST VALUE',
                                              style: TextStyle(
                                                color: AppTheme.tealAccent,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          )
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      plan['saving'],
                                      style: const TextStyle(
                                        color: AppTheme.tealAccent,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    plan['price'],
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  ),
                                  Text(
                                    '/ ${plan['period']}',
                                    style: TextStyle(
                                      color: textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'All Plans Include These Benefits',
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Column(
                    children: _benefits.map((benefit) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 18),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.tealAccent.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                benefit['icon'],
                                color: AppTheme.tealAccent,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    benefit['title'],
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    benefit['subtitle'],
                                    style: TextStyle(
                                      color: textSecondary,
                                      fontSize: 12,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        // Triggers the authenticated core system payment sheet via Google Play infrastructure mapping
                        iapService.buyPremium();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.amberPremium,
                        foregroundColor: isDark ? AppTheme.darkBackground : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(LucideIcons.crown, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'Upgrade Account Now',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'Prepaid plans. Simple one-time payment with no unexpected charges.',
                      style: TextStyle(
                        color: textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}