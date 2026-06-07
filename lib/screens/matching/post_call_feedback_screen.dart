import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../models/auth_provider.dart';
import '../../models/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/coins_earning_overlay.dart';
import '../../widgets/premium_bottom_sheet.dart';

class PostCallFeedbackScreen extends StatefulWidget {
  final String callId;
  final AppUser partner;
  final int durationSeconds;
  final String? disconnectReason;
  final int coinsEarned;

  const PostCallFeedbackScreen({
    super.key,
    required this.callId,
    required this.partner,
    this.durationSeconds = 0,
    this.disconnectReason,
    this.coinsEarned = 0,
  });

  @override
  State<PostCallFeedbackScreen> createState() => _PostCallFeedbackScreenState();
}

class _PostCallFeedbackScreenState extends State<PostCallFeedbackScreen> {
  int _sessionRating = 0;
  bool _isSubmitting = false;
  bool _isSendingFriendRequest = false;
  bool _friendRequestSent = false;
  bool _isAlreadyFriend = false;
  int _initialCoins = 0;
  bool _showCoinsOverlay = false; // Hidden until Cloud Function processes
  int _coinsEarned = 0;
  
  // Call Stats and Ads
  int _callsToday = 0;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;

  final List<String> _feedbackTags = [
    'Spoke too fast',
    'Helped correct me',
    'Great Pronunciation',
    'Excellent Vocabulary',
    'Polite listener',
    'Good feedback',
  ];

  final Set<String> _selectedTags = {};

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    
    // Safely grab initial coins
    _initialCoins = (auth.userData?['coins'] as num?)?.toInt() ?? 0;
    
    debugPrint("\n=========================================");
    debugPrint("[COIN_DEBUG] STEP 4: Feedback Screen Init. Passed earned coins: ${widget.coinsEarned}");
    debugPrint("[COIN_DEBUG] STEP 5: Loaded Initial Coins from Auth State: $_initialCoins");
    debugPrint("=========================================\n");

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _showLimitNotices();
      
      final friendIds = List<String>.from(auth.userData?['friendIds'] ?? []);
      final partnerId = widget.partner.phoneNumber ?? widget.partner.uid;
      
      if (friendIds.contains(partnerId)) {
        setState(() {
          _isAlreadyFriend = true;
          _friendRequestSent = true;
        });
      }

      await _processDailyLimitsAndAds();
    });
  }
  
  void _showLimitNotices() {
    if (widget.disconnectReason == 'limit_10_min') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Call reached the 10-minute session limit. Send a friend request to talk longer next time!'),
        duration: Duration(seconds: 4),
        backgroundColor: AppTheme.coralAction,
      ));
    } else if (widget.disconnectReason == 'limit_daily') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Your 60-minute daily free limit has been reached. Upgrade to premium for unlimited calls!'),
        duration: Duration(seconds: 4),
        backgroundColor: AppTheme.coralAction,
      ));
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => const PremiumBottomSheet(),
      );
    }
  }

  Future<void> _processDailyLimitsAndAds() async {
    final auth = context.read<AuthProvider>();
    final myPhone = auth.userData?['phoneNumber'] ?? FirebaseAuth.instance.currentUser?.phoneNumber;
    if (myPhone == null) return;

    final firestore = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'talktandem');

    try {
      final now = DateTime.now();
      final todayStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final minutes = (widget.durationSeconds / 60).ceil().clamp(1, 999);

      // 1. Process ending the call session via secure Cloud Function
      print("[TalkTandem PostCallFeedback] Calling endCallSession Cloud Function...");
      
      final fetchedCoins = await auth.firestore.endCallSession(
        widget.callId,
        durationMinutes: minutes,
        durationSeconds: widget.durationSeconds,
        dateStr: todayStr,
      );

      // 2. Reload user data to get updated stats pushed by the server
      await auth.loadUserData(auth.uid ?? '');

      // 2.5. Update call history logs locally in Firestore (if the call lasted > 5 seconds)
      if (widget.durationSeconds > 5) {
        try {
          // Write to nested call_history subcollection (Personal History) - allowed by rules
          final partnerPhone = widget.partner.phoneNumber ?? widget.partner.uid;
          final callHistoryData = {
            'callId': widget.callId,
            'participantIds': [myPhone, partnerPhone],
            'participantNames': {
              myPhone: auth.userData?['name'] ?? 'User',
              partnerPhone: widget.partner.name,
            },
            'participantAvatars': {
              myPhone: auth.userData?['avatarUrl'],
              partnerPhone: widget.partner.avatarUrl,
            },
            'status': 'ended',
            'startedAt': Timestamp.fromDate(now.subtract(Duration(seconds: widget.durationSeconds))),
            'endedAt': FieldValue.serverTimestamp(),
            'durationMinutes': minutes,
          };
          await firestore.collection('users').doc(myPhone).collection('call_history').doc(widget.callId).set(callHistoryData);

          // Reload user data to synchronize local Provider state
          await auth.loadUserData(auth.uid ?? '');
        } catch (statsError) {
          debugPrint("[TalkTandem Call Stats] Warning: failed to write user stats to Firestore: $statsError");
        }
      }
      
      if (mounted) {
        setState(() {
          _coinsEarned = fetchedCoins;
          if (_coinsEarned > 0) {
            _showCoinsOverlay = true;
          }
        });
      }

      // Get the updated daily calls count from reloaded data
      _callsToday = (auth.userData?['dailyCallsCount'] as num?)?.toInt() ?? 0;

      // 3. Pre-Load Correct Ad
      final isPremium = (auth.userData?['isPremium'] as bool?) ?? false;
      if (!isPremium) {
        if (_callsToday % 10 == 0) {
          _loadRewardedAd();
        } else if (_callsToday % 3 == 0) {
          _loadInterstitialAd();
        }
      }
      
      // Cleanup WebRTC logic silently in background
      await _cleanupWebRTC(firestore);
      
    } catch (e) {
      debugPrint("[Post Call Stats Error]: $e");
    }
  }

  void _loadInterstitialAd() {
    InterstitialAd.load(
      adUnitId: Platform.isAndroid ? 'ca-app-pub-3940256099942544/1033173712' : 'ca-app-pub-3940256099942544/4411468910',
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) { ad.dispose(); _navigateHome(); },
            onAdFailedToShowFullScreenContent: (ad, error) { ad.dispose(); _navigateHome(); }
          );
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (error) => debugPrint('Interstitial Ad failed to load: $error'),
      ),
    );
  }

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: Platform.isAndroid ? 'ca-app-pub-3940256099942544/5224354917' : 'ca-app-pub-3940256099942544/1712409664',
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) { ad.dispose(); _navigateHome(); },
            onAdFailedToShowFullScreenContent: (ad, error) { ad.dispose(); _navigateHome(); }
          );
          _rewardedAd = ad;
        },
        onAdFailedToLoad: (error) => debugPrint('Rewarded Ad failed to load: $error'),
      ),
    );
  }

  void _processExitAction() {
    final auth = context.read<AuthProvider>();
    final isPremium = (auth.userData?['isPremium'] as bool?) ?? false;
    if (isPremium) {
      _navigateHome();
      return;
    }
    if (_rewardedAd != null) {
      _rewardedAd!.show(onUserEarnedReward: (ad, reward) {
        debugPrint("User earned reward");
      });
    } else if (_interstitialAd != null) {
      _interstitialAd!.show();
    } else {
      _navigateHome();
    }
  }

  void _navigateHome() {
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _cleanupWebRTC(FirebaseFirestore firestore) async {
    debugPrint("[TalkTandem Cleanups] Initiating WebRTC cleanup for callId: ${widget.callId}");
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
    } catch (cleanupError) {
      debugPrint("[TalkTandem Cleanups] Warning: signaling cleanup issue: $cleanupError");
    }
  }

  Future<void> _skipFeedback() async {
    _processExitAction();
  }

  Future<void> _sendFriendRequest() async {
    if (_isAlreadyFriend) return; // Guard logic
    
    final auth = context.read<AuthProvider>();
    final uid = auth.uid;
    final me = auth.appUser;
    if (uid == null || me == null) return;

    setState(() => _isSendingFriendRequest = true);

    try {
      await auth.firestore.sendFriendRequest(
        fromUid: uid,
        me: me,
        toUid: widget.partner.uid,
        toName: widget.partner.name,
        toAvatar: widget.partner.avatarUrl,
      );

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
    if (_sessionRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating before submitting.')),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final uid = auth.uid;
    if (uid == null) return;

    setState(() => _isSubmitting = true);

    try {
      final partnerPhone = widget.partner.phoneNumber ?? widget.partner.uid;

      // Centralized submission (Cloud function awards +25 coins safely)
      await auth.firestore.submitCallFeedback(
        callId: widget.callId,
        raterId: uid,
        ratedUserId: partnerPhone,
        rating: _sessionRating,
        tags: _selectedTags.toList(),
      );

      final me = auth.appUser;
      if (me != null) {
        await auth.firestore.getOrCreateConversation(
          myUid: uid,
          me: me,
          partner: widget.partner,
        );
      }

      await auth.loadUserData(uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thanks! +25 Coins earned for your feedback.')),
        );
      }
      
      _processExitAction();
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save feedback: $e')),
      );
      setState(() => _isSubmitting = false);
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

    return Stack(
      children: [
        Scaffold(
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
                    _isAlreadyFriend ? LucideIcons.userCheck : (_friendRequestSent ? Icons.check_circle_outline : LucideIcons.userPlus),
                    size: 16,
                  ),
                  label: Text(_isAlreadyFriend ? 'Friends' : (_friendRequestSent ? 'Sent' : 'Add Friend')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (_friendRequestSent || _isAlreadyFriend) ? Colors.grey : AppTheme.tealAccent,
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
            _buildRatingRow('Session Rating', _sessionRating, (rating) {
              setState(() => _sessionRating = rating);
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
      ),
      if (_showCoinsOverlay)
          CoinsEarningOverlay(
            coinsEarned: _coinsEarned,
            initialCoins: _initialCoins,
            onDismiss: () {
              setState(() {
                _showCoinsOverlay = false;
              });
            },
          ),
      ],
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