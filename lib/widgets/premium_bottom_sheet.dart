import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class PremiumBottomSheet extends StatelessWidget {
  const PremiumBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final textSecondary = AppTheme.getSecondaryTextColor(context);
    final surfaceColor = AppTheme.getSurfaceColor(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).dividerColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Premium Upgrade Lounge',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.amberPremium,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Unlock the ultimate matching experience.',
            style: TextStyle(color: textSecondary),
          ),
          const SizedBox(height: 32),
          
          _buildFeatureRow(context, Icons.check_circle, 'Gender Filter Unlock', AppTheme.emeraldGreen),
          const SizedBox(height: 16),
          _buildFeatureRow(context, Icons.check_circle, 'Regional Targeting', AppTheme.emeraldGreen),
          const SizedBox(height: 16),
          _buildFeatureRow(context, Icons.check_circle, 'Ad-free matching', AppTheme.emeraldGreen),
          
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: _buildPricingCard(
                  context: context,
                  title: '1 Month',
                  price: '₹99',
                  isPopular: false,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildPricingCard(
                  context: context,
                  title: '3 Months',
                  price: '₹249',
                  isPopular: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.amberPremium,
                foregroundColor: Colors.black,
              ),
              child: const Text('Upgrade Now', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(BuildContext context, IconData icon, String text, Color iconColor) {
    final textPrimary = AppTheme.getTextColor(context);
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 12),
        Text(text, style: TextStyle(color: textPrimary, fontSize: 16)),
      ],
    );
  }

  Widget _buildPricingCard({
    required BuildContext context,
    required String title,
    required String price,
    required bool isPopular,
  }) {
    final textPrimary = AppTheme.getTextColor(context);
    final textSecondary = AppTheme.getSecondaryTextColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isPopular 
        ? AppTheme.amberPremium.withOpacity(0.1) 
        : (isDark ? AppTheme.darkBackground : AppTheme.lightBackground);
    final borderColor = isPopular ? AppTheme.amberPremium : AppTheme.getBorderColor(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBgColor,
        border: Border.all(
          color: borderColor,
          width: isPopular ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          if (isPopular) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.amberPremium,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'POPULAR',
                style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(title, style: TextStyle(color: textSecondary)),
          const SizedBox(height: 8),
          Text(
            price,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
