import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class ReportBottomSheet extends StatefulWidget {
  final VoidCallback onSubmit;

  const ReportBottomSheet({super.key, required this.onSubmit});

  @override
  State<ReportBottomSheet> createState() => _ReportBottomSheetState();
}

class _ReportBottomSheetState extends State<ReportBottomSheet> {
  final List<String> _reasons = [
    'Harassment or Bullying',
    'Adult Content',
    'Spam or Scam',
    'Underage User',
    'Other'
  ];
  
  String? _selectedReason;

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppTheme.getTextColor(context);
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Report User',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.errorRed,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please select a reason for reporting this user. The call will be ended immediately.',
            style: TextStyle(color: textSecondary),
          ),
          const SizedBox(height: 16),
          
          ..._reasons.map((reason) => RadioListTile<String>(
            title: Text(reason, style: TextStyle(color: textPrimary)),
            value: reason,
            groupValue: _selectedReason,
            activeColor: AppTheme.errorRed,
            contentPadding: EdgeInsets.zero,
            onChanged: (value) {
              setState(() {
                _selectedReason = value;
              });
            },
          )),
          
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selectedReason != null ? widget.onSubmit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.errorRed,
                foregroundColor: Colors.white,
              ),
              child: const Text('Submit Report & End Call'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
