import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../models/auth_provider.dart';
import '../../models/models.dart'; 
import '../../theme/app_theme.dart';
import '../../widgets/premium_bottom_sheet.dart';
import '../../widgets/admob_banner_widget.dart';

// FIXED IMPORT PATH HERE:
import 'active_call_screen.dart';

class MatchingScreen extends StatefulWidget {
  const MatchingScreen({super.key});

  @override
  State<MatchingScreen> createState() => _MatchingScreenState();
}

class _MatchingScreenState extends State<MatchingScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'talktandem');
  StreamSubscription<DocumentSnapshot>? _poolSubscription;
  
  bool _isSearching = false;
  String _genderFilter = 'Any Gender';

  String? _connectingToPartnerName;

  Timer? _countdownTimer;
  Timer? _searchPollingTimer;
  int _searchTimeRemaining = 45;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void dispose() {
    _cleanupMatchmaking();
    _pulseController.dispose();
    super.dispose();
  }

  void _cleanupMatchmaking() {
    _poolSubscription?.cancel();
    _poolSubscription = null;
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _searchPollingTimer?.cancel();
    _searchPollingTimer = null;
    _pulseController.stop();
    _pulseController.reset();
  }

  void _onSearchTimeout() async {
    _cleanupMatchmaking();
    setState(() {
      _isSearching = false;
      _connectingToPartnerName = null;
    });

    final auth = context.read<AuthProvider>();
    final phone = FirebaseAuth.instance.currentUser?.phoneNumber ?? auth.userData?['phoneNumber'];
    
    if (phone != null) {
      try {
        await _firestore.collection('matchmaking_pool').doc(phone).delete();
      } catch (e) {
        debugPrint("[TalkTandem Matchmaking] Error removing self from pool: $e");
      }
    }

    _showTimeoutOptionsDialog();
  }

  void _showTimeoutOptionsDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final surface = AppTheme.getSurfaceColor(ctx);
        final textPrimary = AppTheme.getTextColor(ctx);
        final textSecondary = AppTheme.getSecondaryTextColor(ctx);

        if (_genderFilter == 'Any Gender') {
          return AlertDialog(
            backgroundColor: surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'No Partner Connected',
              style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Estimated connection time expired. Would you like to try searching again?',
              style: TextStyle(color: textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _toggleSearch(); 
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.tealAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Try Again', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        } else {
          return AlertDialog(
            backgroundColor: surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'No $_genderFilter Partners Found',
              style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
            ),
            content: Text(
              'No $_genderFilter partners are currently in the queue right now. Would you like to expand your search to find any gender, or retry filtering by $_genderFilter?',
              style: TextStyle(color: textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _toggleSearch(); 
                },
                child: Text('Retry $_genderFilter', style: const TextStyle(color: AppTheme.tealAccent, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _genderFilter = 'Any Gender'; 
                  });
                  _toggleSearch(); 
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.tealAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Find Any Gender', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        }
      },
    );
  }

  Future<void> _toggleSearch() async {
    final auth = context.read<AuthProvider>();
    final uid = auth.uid;
    final me = auth.appUser;
    if (uid == null || me == null) return;

    final phone = FirebaseAuth.instance.currentUser?.phoneNumber ?? auth.userData?['phoneNumber'];
    if (phone == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number not found. Cannot start matchmaking.')),
      );
      return;
    }

    if (_isSearching) {
      setState(() {
        _isSearching = false;
        _connectingToPartnerName = null;
      });
      _cleanupMatchmaking();
      await _firestore.collection('matchmaking_pool').doc(phone).delete();
      return;
    }

    // Daily Limit Check Before Searching
    final today = "${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}";
    final lastCallDate = auth.userData?['lastCallDate'] as String?;
    final isPremium = (auth.userData?['isPremium'] as bool?) ?? false;
    
    int dailyTalkSeconds = 0;
    if (lastCallDate == today) {
      dailyTalkSeconds = (auth.userData?['dailyTalkSeconds'] as num?)?.toInt() ?? 0;
    }

    if (!isPremium && dailyTalkSeconds >= 90 * 60) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Daily free limit of 90 minutes reached. Connect with friends directly or wait until tomorrow!'),
          backgroundColor: AppTheme.coralAction,
          duration: Duration(seconds: 5),
        ),
      );
      return;
    }

    setState(() {
      _isSearching = true;
      _searchTimeRemaining = Random().nextInt(21) + 25; // Random number between 25 and 45
    });
    _pulseController.repeat();

    try {
      debugPrint("[TalkTandem Matchmaking] Scanning for immediate match...");
      final partnerData = await _findAndClaimPartner(phone, me);

      if (partnerData != null) {
        final partner = partnerData['partner'] as AppUser;
        final callId = partnerData['callId'] as String;

        setState(() {
          _connectingToPartnerName = partner.name;
        });

        debugPrint("[TalkTandem Matchmaking] Instant match found. Waiting visual buffer...");
        await Future.delayed(const Duration(milliseconds: 2500));
        _cleanupMatchmaking();
        if (!mounted) return;

        debugPrint("[TalkTandem Matchmaking] Navigating to active call as Caller.");
        _goToCallScreen(callId, partner, isCaller: true);
        return;
      }

      debugPrint("[TalkTandem Matchmaking] No immediate matches. Joining pool queue...");
      final myPoolRef = _firestore.collection('matchmaking_pool').doc(phone);
      await myPoolRef.set({
        'uid': uid,
        'name': me.name,
        'avatarUrl': me.avatarUrl,
        'gender': me.gender.isNotEmpty ? me.gender : (auth.userData?['gender'] ?? 'Male'),
        'status': 'waiting',
        'createdAt': FieldValue.serverTimestamp(),
        'callId': null,
        'partnerId': null,
        'phoneNumber': phone,
      });

      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() {
          if (_searchTimeRemaining > 0) {
            _searchTimeRemaining--;
          } else {
            _onSearchTimeout();
          }
        });
      });

      _searchPollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
        if (!mounted || !_isSearching) return;
        final partnerData = await _findAndClaimPartner(phone, me);
        if (partnerData != null) {
          _cleanupMatchmaking();
          final partner = partnerData['partner'] as AppUser;
          final callId = partnerData['callId'] as String;
          debugPrint("[TalkTandem Matchmaking] Polling found a match! Navigating as Caller.");
          _goToCallScreen(callId, partner, isCaller: true);
        }
      });

      _poolSubscription = myPoolRef.snapshots().listen((snapshot) async {
        if (!snapshot.exists || !mounted) return;
        final data = snapshot.data();

        if (data != null && data['status'] == 'matched' && data['callId'] != null) {
          debugPrint("[TalkTandem Matchmaking] Someone claimed us from queue! Partner ID: ${data['partnerId']}");
          final callId = data['callId'];
          final partnerId = data['partnerId']; 
          _cleanupMatchmaking();

          final partnerDoc = await _firestore.collection('users').doc(partnerId).get();
          if (!mounted) return;

          AppUser partner = AppUser.fromMap(partnerId, partnerDoc.data() ?? {});
          
          await _firestore.collection('matchmaking_pool').doc(phone).delete();

          setState(() {
            _connectingToPartnerName = partner.name;
          });

          await Future.delayed(const Duration(milliseconds: 2500));
          if (!mounted) return;

          debugPrint("[TalkTandem Matchmaking] Navigating to active call as Callee.");
          _goToCallScreen(callId, partner, isCaller: false);
        }
      });

    } catch (e) {
      debugPrint("[TalkTandem Matchmaking] Pool entry error: $e");
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _connectingToPartnerName = null;
      });
      _cleanupMatchmaking();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Matchmaking error: $e')),
      );
    }
  }

  Future<Map<String, dynamic>?> _findAndClaimPartner(String myPhone, AppUser me) async {
    try {
      final snapshot = await _firestore.collection('matchmaking_pool').get();
      
      List<DocumentSnapshot> candidates = [];
      for (var doc in snapshot.docs) {
        if (doc.id == myPhone) continue; 

        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        if (data['status'] != 'waiting') continue; 

        if (_genderFilter != 'Any Gender') {
          final partnerGender = data['gender'] as String? ?? 'Male';
          if (partnerGender.toLowerCase() != _genderFilter.toLowerCase()) {
            continue; 
          }
        }

        candidates.add(doc);
      }

      if (candidates.isEmpty) return null;

      candidates.sort((a, b) {
        final dataA = a.data() as Map<String, dynamic>;
        final dataB = b.data() as Map<String, dynamic>;
        final timeA = dataA['createdAt'] as Timestamp?;
        final timeB = dataB['createdAt'] as Timestamp?;
        if (timeA == null && timeB == null) return 0;
        if (timeA == null) return 1;
        if (timeB == null) return -1;
        return timeA.compareTo(timeB);
      });

      for (var doc in candidates) {
        final partnerPhone = doc.id; 
        final partnerPoolRef = _firestore.collection('matchmaking_pool').doc(partnerPhone);

        try {
          debugPrint("[TalkTandem Matchmaking] Transaction trying to claim: $partnerPhone");
          final callId = await _firestore.runTransaction<String?>((transaction) async {
            final partnerDoc = await transaction.get(partnerPoolRef);
            if (!partnerDoc.exists || partnerDoc.data()?['status'] != 'waiting') {
              debugPrint("[TalkTandem Matchmaking] Claim failed, partner no longer waiting.");
              return null; 
            }

            final generatedCallId = '${partnerPhone}_${myPhone}_${DateTime.now().millisecondsSinceEpoch}';

            transaction.update(partnerPoolRef, {
              'status': 'matched',
              'callId': generatedCallId,
              'partnerId': myPhone, 
            });

            return generatedCallId;
          });

          if (callId != null) {
            debugPrint("[TalkTandem Matchmaking] Successfully locked partner with CallID: $callId");
            final partnerUserDoc = await _firestore.collection('users').doc(partnerPhone).get();
            AppUser partner = AppUser.fromMap(
              partnerPhone, 
              partnerUserDoc.data() ?? (doc.data() as Map<String, dynamic>)
            );

            await _firestore.collection('matchmaking_pool').doc(myPhone).delete();
            return {'callId': callId, 'partner': partner};
          }
        } catch (e) {
          debugPrint("[TalkTandem Matchmaking] Transaction error on partner $partnerPhone: $e");
        }
      }
    } catch (e) {
      debugPrint("[TalkTandem Matchmaking] Polling search error: $e");
    }
    return null;
  }

  void _goToCallScreen(String callId, AppUser partner, {required bool isCaller}) {
    if (!mounted) return;
    setState(() {
      _isSearching = false;
      _connectingToPartnerName = null;
    });
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActiveCallScreen(
          callId: callId,
          partner: partner,
          isCaller: isCaller,
        ),
      ),
    );
  }

  void _selectFilter(String label) {
    setState(() => _genderFilter = label);
  }

  ImageProvider? _getAvatarProvider(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.isEmpty) return null;
    if (avatarUrl.startsWith('http')) {
      return NetworkImage(avatarUrl);
    }
    return AssetImage(avatarUrl);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final me = auth.appUser;
    final textSecondaryColor = AppTheme.getSecondaryTextColor(context);
    final surfaceColor = AppTheme.getSurfaceColor(context);

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Partner Gender',
              style: TextStyle(color: textSecondaryColor, fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                _buildFilterPill('Any Gender'),
                const SizedBox(width: 12),
                _buildFilterPill('Male'),
                const SizedBox(width: 12),
                _buildFilterPill('Female'),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_isSearching)
                    ...List.generate(3, (index) {
                      return AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Opacity(
                            opacity: (1.0 - _pulseController.value).clamp(0.0, 1.0),
                            child: Transform.scale(
                              scale: 1.0 + (_pulseController.value * 1.5) + (index * 0.4),
                              child: Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppTheme.tealAccent.withValues(alpha: 0.5), width: 2),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    }),
                  
                  Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isSearching ? AppTheme.tealAccent.withValues(alpha: 0.15) : AppTheme.tealAccent.withValues(alpha: 0.08),
                      border: Border.all(
                        color: _connectingToPartnerName != null 
                            ? AppTheme.amberPremium 
                            : AppTheme.tealAccent.withValues(alpha: 0.4), 
                        width: _connectingToPartnerName != null ? 3 : 2
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: ClipOval(
                        child: _connectingToPartnerName != null
                            ? Container(
                                color: AppTheme.amberPremium.withOpacity(0.15),
                                child: const Icon(
                                  LucideIcons.phoneCall,
                                  size: 48,
                                  color: AppTheme.amberPremium,
                                ),
                              )
                            : (me?.avatarUrl != null && me!.avatarUrl!.isNotEmpty)
                                ? CircleAvatar(
                                    backgroundImage: _getAvatarProvider(me.avatarUrl),
                                    backgroundColor: AppTheme.tealAccent,
                                  )
                                : Container(
                                    color: AppTheme.tealAccent,
                                    alignment: Alignment.center,
                                    child: Text(
                                      (me?.name ?? 'U').isNotEmpty ? me!.name[0].toUpperCase() : '?',
                                      style: const TextStyle(
                                        fontSize: 48,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          Container(
            width: double.infinity,
            alignment: Alignment.center,
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            child: const AdmobBannerWidget(), 
          ),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _connectingToPartnerName != null
                      ? 'Connecting with $_connectingToPartnerName...'
                      : (_isSearching ? 'Scanning for online practice partners...' : 'Choose a filter and start your practice call'),
                  key: ValueKey(_connectingToPartnerName ?? _isSearching.toString()),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _connectingToPartnerName != null
                        ? AppTheme.amberPremium
                        : (_isSearching ? AppTheme.tealAccent : textSecondaryColor),
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _connectingToPartnerName != null ? null : _toggleSearch,
                icon: Icon(_isSearching ? LucideIcons.phoneOff : LucideIcons.phone, size: 22),
                label: Text(
                  _isSearching ? 'Stop Search • $_searchTimeRemaining s' : 'Start Call', 
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isSearching ? AppTheme.coralAction : AppTheme.tealAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill(String label) {
    final textPrimaryColor = AppTheme.getTextColor(context);
    final surfaceColor = AppTheme.getSurfaceColor(context);
    final borderColor = AppTheme.getBorderColor(context);
    final isSelected = _genderFilter == label;

    return GestureDetector(
      onTap: () => _selectFilter(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.tealAccent.withValues(alpha: 0.2) : surfaceColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isSelected ? AppTheme.tealAccent : borderColor),
        ),
        child: Text(
          label, 
          style: TextStyle(
            color: isSelected ? AppTheme.tealAccent : textPrimaryColor, 
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}