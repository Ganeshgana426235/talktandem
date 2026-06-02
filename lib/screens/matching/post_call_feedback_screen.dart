import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/auth_provider.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';

class PostCallFeedbackScreen extends StatefulWidget {
  final String callId;
  final AppUser partner;

  const PostCallFeedbackScreen({
    super.key,
    required this.callId,
    required this.partner,
  });

  @override
  State<PostCallFeedbackScreen> createState() => _PostCallFeedbackScreenState();
}

class _PostCallFeedbackScreenState extends State<PostCallFeedbackScreen> {
  int _politenessRating = 0;
  int _clarityRating = 0;
  bool _isSubmitting = false;
  bool _isSendingFriendRequest = false;
  bool _friendRequestSent = false;

  final List<String> _feedbackTags = [
    'Spoke too fast',
    'Helped correct me',
    'Great Pronunciation',
    'Excellent Vocabulary',
    'Polite listener',
    'Good feedback',
  ];

  final Set<String> _selectedTags = {};

  Future<void> _cleanupWebRTC(FirebaseFirestore firestore) async {
    debugPrint("[TalkTandem Cleanups] Initiating WebRTC signaling document cleanup for callId: ${widget.callId}");
    try {
      final callRef = firestore.collection('calls').doc(widget.callId);
      final callerCands = await callRef.collection('callerCandidates').get();
      for (var doc in callerCands.docs) {
        await doc.reference.delete();
      }
      final calleeCands = await callRef.collection('calleeCandidates').get();
      for (var doc in calleeCands.docs) {
        await doc.reference.delete();
      }
      await callRef.delete();
      debugPrint("[TalkTandem Cleanups] WebRTC signaling cleanup completed successfully.");
    } catch (cleanupError) {
      debugPrint("[TalkTandem Cleanups] Warning: signaling cleanup encountered an issue: $cleanupError");
    }
  }

  Future<void> _skipFeedback() async {
    final auth = context.read<AuthProvider>();
    final uid = auth.uid;
    if (uid == null) return;

    setState(() => _isSubmitting = true);

    try {
      final firestore = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'talktandem',
      );

      await firestore.collection('calls').doc(widget.callId).update({'status': 'ended'});
      await _cleanupWebRTC(firestore);

      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not skip evaluation: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _sendFriendRequest() async {
    final auth = context.read<AuthProvider>();
    final uid = auth.uid;
    final me = auth.appUser;
    if (uid == null || me == null) return;

    setState(() => _isSendingFriendRequest = true);

    try {
      final firestore = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'talktandem',
      );

      final partnerPhone = widget.partner.phoneNumber ?? widget.partner.uid;

      await firestore
          .collection('users')
          .doc(partnerPhone)
          .collection('friend_requests')
          .doc(uid)
          .set({
        'senderId': uid,
        'senderName': me.name,
        'senderAvatarUrl': me.avatarUrl,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        _friendRequestSent = true;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Friend request sent to ${widget.partner.name}!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send friend request: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSendingFriendRequest = false);
    }
  }

  void _showReportFraudDialog() {
    final textPrimary = AppTheme.getTextColor(context);
    final surfaceColor = AppTheme.getSurfaceColor(context);
    final textSecondary = AppTheme.getSecondaryTextColor(context);
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: surfaceColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            'Report Fraud / Abuse',
            style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Please describe the fraudulent behavior or abusive language observed:',
                style: TextStyle(color: textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                maxLines: 3,
                style: TextStyle(color: textPrimary),
                decoration: InputDecoration(
                  hintText: 'Enter details...',
                  hintStyle: TextStyle(color: textSecondary.withOpacity(0.5)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                final reason = controller.text.trim();
                if (reason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter report description details.')),
                  );
                  return;
                }
                Navigator.of(context).pop();
                await _submitFraudReport(reason);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.coralAction,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Submit Report', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitFraudReport(String reason) async {
    final auth = context.read<AuthProvider>();
    final uid = auth.uid;
    if (uid == null) return;

    setState(() => _isSubmitting = true);

    try {
      final firestore = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'talktandem',
      );

      final partnerPhone = widget.partner.phoneNumber ?? widget.partner.uid;

      await firestore.collection('reports').add({
        'reporterId': uid,
        'reportedUserId': partnerPhone,
        'callId': widget.callId,
        'type': 'fraud_harassment',
        'details': reason,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thank you. The profile has been logged for evaluation.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit report: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitFeedback() async {
    if (_politenessRating == 0 || _clarityRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please rate both categories before submitting.')),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final uid = auth.uid;
    if (uid == null) return;

    setState(() => _isSubmitting = true);

    try {
      final firestore = FirebaseFirestore.instanceFor(
        app: Firebase.app(),
        databaseId: 'talktandem',
      );

      await firestore.collection('calls').doc(widget.callId).update({'status': 'ended'});
      
      final partnerPhone = widget.partner.phoneNumber ?? widget.partner.uid;

      await firestore.collection('feedback').add({
        'callId': widget.callId,
        'raterId': uid,
        'ratedUserId': partnerPhone,
        'politenessRating': _politenessRating,
        'clarityRating': _clarityRating,
        'tags': _selectedTags.toList(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      final myPhone = auth.userData?['phoneNumber'] ?? FirebaseAuth.instance.currentUser?.phoneNumber;
      if (myPhone != null) {
        await firestore.collection('users').doc(myPhone).update({
          'xp': FieldValue.increment(25),
        });
      }

      final me = auth.appUser;
      if (me != null) {
        await auth.firestore.getOrCreateConversation(
          myUid: uid,
          me: me,
          partner: widget.partner,
        );
      }

      await _cleanupWebRTC(firestore);

      await auth.loadUserData(uid);
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks! +25 XP earned for your feedback.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save feedback: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  ImageProvider? _getAvatarProvider(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.isEmpty) return null;
    if (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://') || avatarUrl.startsWith('http') || avatarUrl.startsWith('https')) {
      return NetworkImage(avatarUrl);
    }
    return AssetImage(avatarUrl);
  }

  @override
  Widget build(BuildContext context) {
    final textPrimary = AppTheme.getTextColor(context);
    final textSecondary = AppTheme.getSecondaryTextColor(context);
    final surfaceColor = AppTheme.getSurfaceColor(context);
    final borderColor = AppTheme.getBorderColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Evaluation',
            style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _skipFeedback,
            child: const Text(
              'Skip',
              style: TextStyle(
                color: AppTheme.tealAccent,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundImage: _getAvatarProvider(widget.partner.avatarUrl),
              backgroundColor: AppTheme.tealAccent,
              child: (widget.partner.avatarUrl == null || widget.partner.avatarUrl!.isEmpty)
                  ? Text(
                      widget.partner.name.isNotEmpty
                          ? widget.partner.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              'How was your session with ${widget.partner.name}?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: (_isSendingFriendRequest || _friendRequestSent) ? null : _sendFriendRequest,
                  icon: Icon(
                    _friendRequestSent ? Icons.check_circle_outline : LucideIcons.userPlus,
                    size: 16,
                  ),
                  label: Text(_friendRequestSent ? 'Sent' : 'Add Friend'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _friendRequestSent ? Colors.grey : AppTheme.tealAccent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.teal.withOpacity(0.12),
                    disabledForegroundColor: AppTheme.tealAccent.withOpacity(0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                OutlinedButton.icon(
                  onPressed: _showReportFraudDialog,
                  icon: const Icon(LucideIcons.alertOctagon, size: 16, color: AppTheme.coralAction),
                  label: const Text('Report Fraud', style: TextStyle(color: AppTheme.coralAction)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.coralAction, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            _buildRatingRow('Partner Politeness', _politenessRating, (rating) {
              setState(() => _politenessRating = rating);
            }),
            const SizedBox(height: 24),
            _buildRatingRow('Speaking Clarity', _clarityRating, (rating) {
              setState(() => _clarityRating = rating);
            }),
            const SizedBox(height: 32),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Select appropriate tags:',
                style: TextStyle(
                  color: textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 12,
              children: _feedbackTags.map((tag) {
                final isSelected = _selectedTags.contains(tag);
                return FilterChip(
                  label: Text(tag),
                  selected: isSelected,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _selectedTags.add(tag);
                      } else {
                        _selectedTags.remove(tag);
                      }
                    });
                  },
                  selectedColor: AppTheme.tealAccent.withOpacity(0.2),
                  checkmarkColor: AppTheme.tealAccent,
                  labelStyle: TextStyle(
                    color: isSelected ? AppTheme.tealAccent : textPrimary,
                  ),
                  backgroundColor: surfaceColor,
                  side: BorderSide(
                    color: isSelected ? AppTheme.tealAccent : borderColor,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitFeedback,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.tealAccent,
                  foregroundColor: isDark ? AppTheme.darkBackground : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Submit Feedback',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingRow(
    String label,
    int currentRating,
    ValueChanged<int> onChanged,
  ) {
    final textPrimary = AppTheme.getTextColor(context);

    return Column(
      children: [
        Text(label,
            style: TextStyle(
                color: textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (index) {
            final rating = index + 1;
            return IconButton(
              onPressed: () => onChanged(rating),
              icon: Icon(
                rating <= currentRating ? Icons.star : Icons.star_border,
                color: AppTheme.amberPremium,
                size: 36,
              ),
            );
          }),
        ),
      ],
    );
  }
}