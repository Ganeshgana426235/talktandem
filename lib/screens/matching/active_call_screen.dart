import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:keep_screen_on/keep_screen_on.dart';
import '../../models/auth_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/report_bottom_sheet.dart';
import '../../widgets/premium_bottom_sheet.dart';
import '../../models/models.dart';
import '../../widgets/admob_banner_widget.dart';
import 'post_call_feedback_screen.dart';

class ActiveCallScreen extends StatefulWidget {
  final String callId;
  final AppUser partner;
  final bool isCaller;

  const ActiveCallScreen({
    super.key,
    required this.callId,
    required this.partner,
    required this.isCaller,
  });

  @override
  State<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends State<ActiveCallScreen> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'talktandem');
  
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream; 
  StreamSubscription? _signalingSubscription;
  StreamSubscription? _iceSubscription;

  bool _isMuted = false;
  bool _isSpeakerPhone = true;
  int _selectedActivityIndex = 0; // 0: Topics, 1: Games
  
  // Daily Talk Trackers
  int _startDailySeconds = 0;
  bool _isPremium = false;

  // WebRTC Description Sync Gate
  bool _hasRemoteDescriptionSet = false; 
  final List<RTCIceCandidate> _queuedRemoteIceCandidates = [];
  
  Timer? _callDurationTimer;
  Timer? _diagnosticTimer; 
  int _secondsElapsed = 0;
  late AnimationController _soundWaveController;

  // --- Real-time Game & Prompt Datasets ---
  final List<String> _topicsDataset = [
    "What is your dream travel destination and what would you do first when you arrive?",
    "If you could have dinner with any historical figure, who would it be and why?",
    "Describe your absolute ideal weekend morning from start to finish.",
    "What's the best book, movie, or series you've finished recently and why?",
    "If you could instantly master any professional skill, what would it be?",
    "Tell a story about a funny or unexpected thing that happened to you this week.",
  ];

  final List<Map<String, String>> _wordsDataset = [
    {'word': 'TANDEM', 'clue': 'An arrangement of two people or things working closely together.'},
    {'word': 'FLUENCY', 'clue': 'The ability to speak or write a foreign language easily and accurately.'},
    {'word': 'PROTAGONIST', 'clue': 'The leading character or one of the major characters in a drama.'},
    {'word': 'CINEMATOGRAPHY', 'clue': 'The premium art of making motion pictures.'},
    {'word': 'VOCABULARY', 'clue': 'The total body of words used in a particular language.'},
    {'word': 'RESONANCE', 'clue': 'The physical quality of sound being deep, full, and reverberating.'},
  ];

  final List<Map<String, dynamic>> _triviaDataset = [
    {
      'question': 'Which of these is a direct synonym for "Magnificent"?',
      'options': ['Splendid', 'Trivial', 'Drab', 'Meager'],
      'answer': 0,
    },
    {
      'question': 'What do you call a person who speaks multiple languages fluently?',
      'options': ['Monolingual', 'Polyglot', 'Logophile', 'Sycophant'],
      'answer': 1,
    },
    {
      'question': 'Which country is the origin of the word "Tsunami"?',
      'options': ['China', 'Japan', 'Iceland', 'India'],
      'answer': 1,
    },
    {
      'question': 'Complete the popular idiom: "Kill two birds with one ___"',
      'options': ['Arrow', 'Sling', 'Stone', 'Bullet'],
      'answer': 2,
    }
  ];

  // --- Synced Game State Properties ---
  late String _currentTopic;
  String _activeGameType = "none";
  
  // Game Invitations
  String _gameInviterId = "";
  String _gameInviterName = "";
  bool _isShowingInviteDialog = false;

  // Game states: Word Guesser
  String _wordToGuess = "";
  String _wordClue = "";
  List<String> _guessedLetters = [];
  String _gameTurnId = ""; 
  int _wordGuesserScore = 0;

  // Game states: Trivia
  int _triviaIndex = 0;
  Map<String, int> _triviaAnswers = {}; 
  int _myScore = 0;
  int _partnerScore = 0;

  final Map<String, dynamic> _iceConfiguration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {
        'urls': 'turn:openrelay.metered.ca:80',
        'username': 'openrelayproject',
        'credential': 'openrelayprojectsecret'
      },
      {
        'urls': 'turn:openrelay.metered.ca:443',
        'username': 'openrelayproject',
        'credential': 'openrelayprojectsecret'
      }
    ]
  };

  @override
  void initState() {
    super.initState();
    debugPrint("========== 🛠️ TALKTANDEM AUDIO DIAGNOSTICS STARTING ==========");
    
    // Fetch initial limits mapping for limits tracker
    final auth = context.read<AuthProvider>();
    final today = "${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}";
    if (auth.userData?['lastCallDate'] == today) {
      _startDailySeconds = (auth.userData?['dailyTalkSeconds'] as num?)?.toInt() ?? 0;
    }
    _isPremium = (auth.userData?['isPremium'] as bool?) ?? false;
    
    final random = Random();
    _currentTopic = _topicsDataset[random.nextInt(_topicsDataset.length)];

    KeepScreenOn.turnOn();
    
    _soundWaveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _startTimer();
    _initializeWebRTC();
    _startTrackDiagnosticMonitor();
  }

  void _startTrackDiagnosticMonitor() {
    _diagnosticTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_peerConnection == null) return;
      debugPrint("[ICE State] Connection: ${_peerConnection!.iceConnectionState?.name} | Signaling: ${_peerConnection!.signalingState?.name}");
    });
  }

  @override
  void dispose() {
    KeepScreenOn.turnOff();
    _callDurationTimer?.cancel();
    _diagnosticTimer?.cancel();
    _signalingSubscription?.cancel();
    _iceSubscription?.cancel();
    _localStream?.dispose();
    _remoteStream?.dispose();
    _peerConnection?.dispose();
    _soundWaveController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _callDurationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _hasRemoteDescriptionSet) {
        setState(() {
          _secondsElapsed++;

          // Limit Disconnection Checks
          if (_secondsElapsed >= 10 * 60) {
            // 10 Min Hard Session Limit hit
            _endCallLocally(reason: 'limit_10_min');
          } else if (!_isPremium && (_startDailySeconds + _secondsElapsed) >= 90 * 60) {
            // 90 Min Global Daily Free Limit Hit
            _endCallLocally(reason: 'limit_daily');
          }
        });
      }
    });
  }

  String _getFormattedDuration() {
    final minutes = (_secondsElapsed ~/ 60).toString().padLeft(2, '0');
    final seconds = (_secondsElapsed % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }

  Future<void> _processQueuedCandidates() async {
    if (_peerConnection == null) return;
    for (var candidate in _queuedRemoteIceCandidates) {
      try {
        await _peerConnection!.addCandidate(candidate);
      } catch (e) {
        debugPrint("[WebRTC Error] Adding queued candidate failed: $e");
      }
    }
    _queuedRemoteIceCandidates.clear();
  }

  ImageProvider? _getAvatarProvider(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.isEmpty) return null;
    if (avatarUrl.startsWith('http')) return NetworkImage(avatarUrl);
    return AssetImage(avatarUrl);
  }

  Future<void> _initializeWebRTC() async {
    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': false 
      });

      _peerConnection = await createPeerConnection(_iceConfiguration);

      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      _peerConnection!.onIceConnectionState = (state) {
        if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
            state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
            state == RTCIceConnectionState.RTCIceConnectionStateClosed) {
          _endCallLocally(reason: 'disconnected');
        }
      };
      
      _peerConnection!.onAddStream = (MediaStream stream) {
        setState(() {
          _remoteStream = stream;
        });
      };

      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (event.track.kind == 'audio') {
          if (event.streams.isNotEmpty) {
            setState(() {
              _remoteStream = event.streams[0];
            });
            _remoteStream!.getAudioTracks().forEach((track) {
              track.enabled = true;
            });
          }
        }
      };

      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        _firestore.collection('calls').doc(widget.callId)
            .collection(widget.isCaller ? 'callerCandidates' : 'calleeCandidates')
            .add(candidate.toMap())
            .catchError((err) => debugPrint("[Firestore Error] ICE candidate Sync failed: $err"));
      };

      final callDocRef = _firestore.collection('calls').doc(widget.callId);

      final Map<String, dynamic> mediaConstraints = {
        'mandatory': {
          'OfferToReceiveAudio': true,
          'OfferToReceiveVideo': false,
        },
        'optional': [],
      };

      if (widget.isCaller) {
        RTCSessionDescription offer = await _peerConnection!.createOffer(mediaConstraints);
        await _peerConnection!.setLocalDescription(offer);
        
        await callDocRef.set({
          'offer': offer.toMap(),
          'status': 'active',
          'activeGameType': 'none',
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      _signalingSubscription = callDocRef.snapshots().listen((snapshot) async {
        if (!snapshot.exists) {
          if (_hasRemoteDescriptionSet) _endCallLocally(reason: 'disconnected');
          return;
        }
        
        final data = snapshot.data();
        if (data == null) return;
        
        if (data['status'] == 'ended') {
          _endCallLocally(reason: 'ended_by_partner');
          return;
        }

        if (mounted) {
          final newGameType = data['activeGameType'] as String? ?? 'none';
          final inviterId = data['gameInviterId'] as String? ?? '';
          final inviterName = data['gameInviterName'] as String? ?? 'Your partner';
          
          final myPhone = context.read<AuthProvider>().appUser?.phoneNumber ?? "";

          if (newGameType.startsWith('pending_') && inviterId != myPhone) {
            if (!_isShowingInviteDialog) {
              _isShowingInviteDialog = true;
              _showInviteDialog(newGameType.replaceAll('pending_', ''), inviterName);
            }
          } else if (newGameType == 'none' && _isShowingInviteDialog) {
            Navigator.of(context, rootNavigator: true).pop();
            _isShowingInviteDialog = false;
          }

          setState(() {
            _activeGameType = newGameType;
            _gameInviterId = inviterId;
            _gameInviterName = inviterName;
            
            _wordToGuess = data['wordToGuess'] as String? ?? "";
            _wordClue = data['wordClue'] as String? ?? "";
            _guessedLetters = List<String>.from(data['guessedLetters'] ?? []);
            _gameTurnId = data['gameTurnId'] as String? ?? "";
            _wordGuesserScore = (data['wordGuesserScore'] as num?)?.toInt() ?? 0;

            _triviaIndex = (data['triviaIndex'] as num?)?.toInt() ?? 0;
            _triviaAnswers = Map<String, int>.from(data['triviaAnswers'] ?? {});
            
            final partnerPhone = widget.partner.phoneNumber;
            
            _myScore = (data['score_$myPhone'] as num?)?.toInt() ?? 0;
            _partnerScore = (data['score_$partnerPhone'] as num?)?.toInt() ?? 0;
          });
        }

        if (widget.isCaller) {
          if (data['answer'] != null && !_hasRemoteDescriptionSet) {
            setState(() => _hasRemoteDescriptionSet = true);
            var answer = RTCSessionDescription(data['answer']['sdp'], data['answer']['type']);
            await _peerConnection!.setRemoteDescription(answer);
            await _processQueuedCandidates();
          }
        } else {
          if (data['offer'] != null && !_hasRemoteDescriptionSet) {
            setState(() => _hasRemoteDescriptionSet = true);
            var offer = RTCSessionDescription(data['offer']['sdp'], data['offer']['type']);
            await _peerConnection!.setRemoteDescription(offer);

            RTCSessionDescription answer = await _peerConnection!.createAnswer(mediaConstraints);
            await _peerConnection!.setLocalDescription(answer);
            
            await callDocRef.update({'answer': answer.toMap()});
            await _processQueuedCandidates();
          }
        }
      });

      _iceSubscription = _firestore.collection('calls').doc(widget.callId)
          .collection(widget.isCaller ? 'calleeCandidates' : 'callerCandidates')
          .snapshots().listen((snapshot) {
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.added) {
            var data = change.doc.data();
            if (data != null) {
              var candidate = RTCIceCandidate(
                data['candidate'] as String?, 
                data['sdpMid'] as String?, 
                data['sdpMLineIndex'] as int?
              );
              
              if (_hasRemoteDescriptionSet) {
                _peerConnection!.addCandidate(candidate);
              } else {
                _queuedRemoteIceCandidates.add(candidate);
              }
            }
          }
        }
      });

      Helper.setSpeakerphoneOn(_isSpeakerPhone);
    } catch (e, stacktrace) {
      debugPrint("[WebRTC Critical Failure] Handshake error: $e\n$stacktrace");
    }
  }

  void _nextTopic() {
    final random = Random();
    String nextTopic = _topicsDataset[random.nextInt(_topicsDataset.length)];
    while (nextTopic == _currentTopic) {
      nextTopic = _topicsDataset[random.nextInt(_topicsDataset.length)];
    }
    setState(() {
      _currentTopic = nextTopic;
    });
  }

  Future<void> _inviteToGame(String gameType) async {
    final myPhone = context.read<AuthProvider>().appUser?.phoneNumber ?? "";
    final myName = context.read<AuthProvider>().appUser?.name ?? "Your partner";
    try {
      await _firestore.collection('calls').doc(widget.callId).update({
        'activeGameType': 'pending_$gameType',
        'gameInviterId': myPhone,
        'gameInviterName': myName,
      });
    } catch (e) {
      debugPrint("Error sending game invite: $e");
    }
  }

  void _showInviteDialog(String gameType, String inviterName) {
    final gameName = gameType == 'word_guess' ? 'Word Guesser' : 'Trivia Challenge';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getSurfaceColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Game Invitation', style: TextStyle(color: AppTheme.getTextColor(context), fontWeight: FontWeight.bold)),
        content: Text('$inviterName is inviting you to play $gameName. Do you want to join?', style: TextStyle(color: AppTheme.getSecondaryTextColor(context))),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _isShowingInviteDialog = false;
              _exitGame(); 
            },
            child: const Text('Decline', style: TextStyle(color: AppTheme.coralAction)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _isShowingInviteDialog = false;
              _acceptGame(gameType);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.tealAccent),
            child: const Text('Join', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _acceptGame(String gameType) {
    if (gameType == 'word_guess') {
      _startWordGuesser();
    } else if (gameType == 'trivia') {
      _startTrivia();
    }
  }

  Future<void> _startWordGuesser() async {
    final random = Random();
    final puzzle = _wordsDataset[random.nextInt(_wordsDataset.length)];
    final myPhone = context.read<AuthProvider>().appUser?.phoneNumber ?? "";

    try {
      await _firestore.collection('calls').doc(widget.callId).update({
        'activeGameType': 'word_guess',
        'wordToGuess': puzzle['word'],
        'wordClue': puzzle['clue'],
        'guessedLetters': [],
        'gameTurnId': myPhone, 
        'wordGuesserScore': 0,
      });
    } catch (e) {
      debugPrint("[Game Error] Failed to launch Word Guesser: $e");
    }
  }

  Future<void> _guessLetter(String letter) async {
    final myPhone = context.read<AuthProvider>().appUser?.phoneNumber ?? "";
    if (_gameTurnId != myPhone) return; 

    final updatedGuesses = List<String>.from(_guessedLetters)..add(letter);
    final isHit = _wordToGuess.contains(letter);
    final partnerPhone = widget.partner.phoneNumber;

    bool isCompleted = true;
    for (int i = 0; i < _wordToGuess.length; i++) {
      if (!updatedGuesses.contains(_wordToGuess[i])) {
        isCompleted = false;
        break;
      }
    }

    try {
      final updates = {
        'guessedLetters': updatedGuesses,
        'gameTurnId': partnerPhone, 
      };

      if (isHit) {
        updates['wordGuesserScore'] = _wordGuesserScore + 10;
      }

      if (isCompleted) {
        updates['wordGuesserScore'] = _wordGuesserScore + 50; 
      }

      await _firestore.collection('calls').doc(widget.callId).update(updates);
    } catch (e) {
      debugPrint("[Game Error] Guess processing failed: $e");
    }
  }

  Future<void> _startTrivia() async {
    final myPhone = context.read<AuthProvider>().appUser?.phoneNumber ?? "";
    final partnerPhone = widget.partner.phoneNumber;

    try {
      await _firestore.collection('calls').doc(widget.callId).update({
        'activeGameType': 'trivia',
        'triviaIndex': 0,
        'triviaAnswers': {},
        'score_$myPhone': 0,
        'score_$partnerPhone': 0,
      });
    } catch (e) {
      debugPrint("[Game Error] Failed to launch Trivia: $e");
    }
  }

  Future<void> _submitTriviaAnswer(int index) async {
    final myPhone = context.read<AuthProvider>().appUser?.phoneNumber ?? "";
    if (_triviaAnswers.containsKey(myPhone)) return; 

    final updatedAnswers = Map<String, int>.from(_triviaAnswers)..[myPhone] = index;
    final partnerPhone = widget.partner.phoneNumber;

    final question = _triviaDataset[_triviaIndex];
    final isCorrect = question['answer'] == index;

    try {
      final Map<String, dynamic> updates = {
        'triviaAnswers': updatedAnswers,
      };

      if (isCorrect) {
        updates['score_$myPhone'] = _myScore + 20;
      }

      await _firestore.collection('calls').doc(widget.callId).update(updates);
    } catch (e) {
      debugPrint("[Game Error] Trivia submit failed: $e");
    }
  }

  Future<void> _nextTriviaQuestion() async {
    if (_triviaIndex >= _triviaDataset.length - 1) {
      await _firestore.collection('calls').doc(widget.callId).update({
        'activeGameType': 'none',
      });
      return;
    }

    try {
      await _firestore.collection('calls').doc(widget.callId).update({
        'triviaIndex': _triviaIndex + 1,
        'triviaAnswers': {},
      });
    } catch (e) {
      debugPrint("[Game Error] Failed to advance question: $e");
    }
  }

  Future<void> _exitGame() async {
    try {
      await _firestore.collection('calls').doc(widget.callId).update({
        'activeGameType': 'none',
        'gameInviterId': null,
        'gameInviterName': null,
      });
    } catch (e) {
      debugPrint("[Game Error] Exit failed: $e");
    }
  }

  void _toggleMute() {
    if (_localStream != null) {
      final audioTrack = _localStream!.getAudioTracks().firstOrNull;
      if (audioTrack != null) {
        setState(() {
          _isMuted = !_isMuted;
          audioTrack.enabled = !_isMuted;
        });
      }
    }
  }

  void _toggleSpeakerPhone() {
    setState(() {
      _isSpeakerPhone = !_isSpeakerPhone;
      Helper.setSpeakerphoneOn(_isSpeakerPhone);
    });
  }

  void _showReportSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ReportBottomSheet(
        onSubmit: () {
          Navigator.of(context).pop();
          _endCall();
        },
      ),
    );
  }

  void _endCall() async {
    try {
      await _firestore.collection('calls').doc(widget.callId).update({'status': 'ended'});
    } catch (_) {}
    _endCallLocally(reason: 'user_ended');
  }

  void _endCallLocally({String? reason}) {
    if (!mounted) return;
    if (_isShowingInviteDialog) {
      Navigator.of(context, rootNavigator: true).pop();
      _isShowingInviteDialog = false;
    }
    _cleanupResources();
    
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PostCallFeedbackScreen(
          callId: widget.callId,
          partner: widget.partner,
          durationSeconds: _secondsElapsed,
          disconnectReason: reason,
        ),
      ),
    );
  }

  void _cleanupResources() {
    _signalingSubscription?.cancel();
    _signalingSubscription = null;
    _iceSubscription?.cancel();
    _iceSubscription = null;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final me = auth.appUser;
    
    final textPrimary = AppTheme.getTextColor(context);
    final textSecondary = AppTheme.getSecondaryTextColor(context);
    final surfaceColor = AppTheme.getSurfaceColor(context);
    final borderColor = AppTheme.getBorderColor(context);
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    
    final bool isFullScreenGame = _activeGameType == 'word_guess' || _activeGameType == 'trivia';

    // Advanced Formatting For Time Remaining UI
    int callRemaining = (10 * 60) - _secondsElapsed;
    if(callRemaining < 0) callRemaining = 0;
    
    int dailyRemaining = 0;
    if(!_isPremium) {
       dailyRemaining = (90 * 60) - (_startDailySeconds + _secondsElapsed);
       if(dailyRemaining < 0) dailyRemaining = 0;
    }

    String callTimeStr = "${(callRemaining ~/ 60).toString().padLeft(2,'0')}:${(callRemaining % 60).toString().padLeft(2,'0')}";
    String dailyTimeStr = _isPremium ? "Unlimited" : "${(dailyRemaining ~/ 60).toString().padLeft(2,'0')}:${(dailyRemaining % 60).toString().padLeft(2,'0')}";

    // FULL SCREEN GAME MODE UI
    if (isFullScreenGame) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _endCall();
        },
        child: Scaffold(
          backgroundColor: scaffoldBg,
          body: SafeArea(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  color: surfaceColor,
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatIndicator(
                            icon: LucideIcons.clock,
                            value: "${_getFormattedDuration()} / 10:00",
                            color: AppTheme.tealAccent,
                          ),
                          const SizedBox(height: 4),
                          Text("Daily left: $dailyTimeStr", style: TextStyle(color: textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(_isMuted ? LucideIcons.micOff : LucideIcons.mic, color: _isMuted ? AppTheme.coralAction : textPrimary, size: 22),
                            onPressed: _toggleMute,
                          ),
                          IconButton(
                            icon: Icon(_isSpeakerPhone ? LucideIcons.volume2 : LucideIcons.volumeX, color: _isSpeakerPhone ? AppTheme.tealAccent : textPrimary, size: 22),
                            onPressed: _toggleSpeakerPhone,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    color: scaffoldBg,
                    child: _activeGameType == "word_guess" 
                        ? _buildWordGuesserGameWidget(textPrimary, textSecondary) 
                        : _buildTriviaGameWidget(textPrimary, textSecondary),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // STANDARD SPLIT SCREEN UI
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _endCall();
      },
      child: Scaffold(
        backgroundColor: scaffoldBg,
        body: SafeArea(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                color: surfaceColor,
                child: Row(
                  children: [
                    Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatIndicator(
                            icon: LucideIcons.clock,
                            value: "${_getFormattedDuration()} (Left: $callTimeStr)",
                            color: AppTheme.tealAccent,
                          ),
                          const SizedBox(height: 4),
                          Text("Daily pool remaining: $dailyTimeStr", style: TextStyle(color: textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _hasRemoteDescriptionSet 
                            ? AppTheme.emeraldGreen.withOpacity(0.1) 
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _hasRemoteDescriptionSet ? AppTheme.emeraldGreen : Colors.orange,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _hasRemoteDescriptionSet ? AppTheme.emeraldGreen : Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _hasRemoteDescriptionSet ? "Active Voice Match" : "Establishing line...",
                            style: TextStyle(
                              color: _hasRemoteDescriptionSet ? AppTheme.emeraldGreen : Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                flex: 5,
                child: Container(
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedActivityIndex = 0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: _selectedActivityIndex == 0 ? AppTheme.tealAccent.withOpacity(0.08) : Colors.transparent,
                                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(24)),
                                  border: Border(
                                    bottom: BorderSide(
                                      color: _selectedActivityIndex == 0 ? AppTheme.tealAccent : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  'Topics & Helpers',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _selectedActivityIndex == 0 ? AppTheme.tealAccent : textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedActivityIndex = 1),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: _selectedActivityIndex == 1 ? AppTheme.amberPremium.withOpacity(0.08) : Colors.transparent,
                                  borderRadius: const BorderRadius.only(topRight: Radius.circular(24)),
                                  border: Border(
                                    bottom: BorderSide(
                                      color: _selectedActivityIndex == 1 ? AppTheme.amberPremium : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(LucideIcons.gamepad2, color: AppTheme.amberPremium, size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Realtime Games',
                                      style: TextStyle(
                                        color: _selectedActivityIndex == 1 ? AppTheme.amberPremium : textPrimary,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Expanded(
                        child: _selectedActivityIndex == 0 
                            ? _buildTopicSuggesterPanel(textPrimary, textSecondary) 
                            : _buildGamingConsolePanel(textPrimary, textSecondary),
                      ),
                    ],
                  ),
                ),
              ),

              Expanded(
                flex: 4,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildSideUserCard(
                              name: "${me?.name ?? 'You'} (Me)",
                              avatarUrl: me?.avatarUrl,
                              color: AppTheme.tealAccent,
                              isActive: !_isMuted,
                              isLocal: true,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildSideUserCard(
                              name: widget.partner.name,
                              avatarUrl: widget.partner.avatarUrl,
                              color: AppTheme.amberPremium,
                              isActive: _hasRemoteDescriptionSet,
                              isLocal: false,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildControlButton(
                          icon: _isMuted ? LucideIcons.micOff : LucideIcons.mic,
                          color: _isMuted ? Colors.blue : textPrimary,
                          bgColor: _isMuted ? Colors.blue.withOpacity(0.15) : surfaceColor,
                          onTap: _toggleMute,
                        ),
                        _buildControlButton(
                          icon: LucideIcons.phoneOff,
                          color: Colors.white,
                          bgColor: AppTheme.coralAction,
                          size: 64,
                          onTap: _endCall,
                        ),
                        _buildControlButton(
                          icon: _isSpeakerPhone ? LucideIcons.volume2 : LucideIcons.volumeX,
                          color: _isSpeakerPhone ? Colors.blue : textPrimary,
                          bgColor: _isSpeakerPhone ? Colors.blue.withOpacity(0.15) : surfaceColor,
                          onTap: _toggleSpeakerPhone,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _showReportSheet,
                      icon: const Icon(LucideIcons.flag, color: AppTheme.coralAction, size: 16),
                      label: const Text('Report User', style: TextStyle(color: AppTheme.coralAction)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatIndicator({required IconData icon, required String value, required Color color}) {
    final textPrimary = AppTheme.getTextColor(context);
    final surfaceColor = AppTheme.getSurfaceColor(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(value, style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildSideUserCard({
    required String name,
    required String? avatarUrl,
    required Color color,
    required bool isActive,
    required bool isLocal,
  }) {
    final textPrimary = AppTheme.getTextColor(context);
    final textSecondary = AppTheme.getSecondaryTextColor(context);
    final surfaceColor = AppTheme.getSurfaceColor(context);
    final borderColor = AppTheme.getBorderColor(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isActive ? color : borderColor, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              if (isActive)
                AnimatedBuilder(
                  animation: _soundWaveController,
                  builder: (context, child) {
                    final pulseValue = _soundWaveController.value;
                    return Container(
                      width: 64 + (pulseValue * 12),
                      height: 64 + (pulseValue * 12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: color.withOpacity(0.15),
                      ),
                    );
                  },
                ),
              CircleAvatar(
                radius: 32,
                backgroundImage: _getAvatarProvider(avatarUrl),
                backgroundColor: color.withOpacity(0.2),
                child: (avatarUrl == null || avatarUrl.isEmpty)
                    ? Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive ? AppTheme.emeraldGreen : Colors.grey,
                    border: Border.all(color: surfaceColor, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          Text(
            isLocal ? (_isMuted ? "Muted" : "Active mic") : (_hasRemoteDescriptionSet ? "Connected" : "Loading..."),
            style: TextStyle(
              fontSize: 11,
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicSuggesterPanel(Color textPrimary, Color textSecondary) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.tealAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              "PRACTICE TOPIC",
              style: TextStyle(
                color: AppTheme.tealAccent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Text(
                  '"$_currentTopic"',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: textPrimary,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _nextTopic,
              icon: const Icon(LucideIcons.refreshCw, size: 16),
              label: const Text('Next Suggestion', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.tealAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            alignment: Alignment.center,
            child: const AdmobBannerWidget(), 
          ),
        ],
      ),
    );
  }

  Widget _buildGamingConsolePanel(Color textPrimary, Color textSecondary) {
    if (_activeGameType.startsWith('pending_')) {
      final myPhone = context.read<AuthProvider>().appUser?.phoneNumber ?? "";
      if (_gameInviterId == myPhone) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppTheme.tealAccent),
              const SizedBox(height: 20),
              Text(
                "Waiting for ${widget.partner.name} to accept...",
                style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _exitGame,
                child: const Text("Cancel Invite", style: TextStyle(color: AppTheme.coralAction)),
              )
            ],
          ),
        );
      } else {
        return Center(
          child: Text("Game invitation received...", style: TextStyle(color: textSecondary)),
        );
      }
    }

    if (_activeGameType == "none") {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Select a game to play live with your partner!",
              textAlign: TextAlign.center,
              style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            _buildGameSelectionCard(
              title: "🎮 Word Guesser (Collaborative)",
              desc: "Solve English vocabulary words by guessing letters together turn-by-turn.",
              color: AppTheme.tealAccent,
              onTap: () => _inviteToGame('word_guess'),
            ),
            const SizedBox(height: 12),
            _buildGameSelectionCard(
              title: "🧠 Rapid Trivia Challenge",
              desc: "Race to answer simultaneous general knowledge and grammar quiz questions.",
              color: AppTheme.amberPremium,
              onTap: () => _inviteToGame('trivia'),
            ),
          ],
        ),
      );
    }
    
    return const SizedBox();
  }

  Widget _buildGameSelectionCard({
    required String title,
    required String desc,
    required Color color,
    required VoidCallback onTap,
  }) {
    final textPrimary = AppTheme.getTextColor(context);
    final textSecondary = AppTheme.getSecondaryTextColor(context);
    final borderColor = AppTheme.getBorderColor(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.08), Colors.transparent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(desc, style: TextStyle(color: textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildWordGuesserGameWidget(Color textPrimary, Color textSecondary) {
    final myPhone = context.read<AuthProvider>().appUser?.phoneNumber ?? "";
    final isMyTurn = _gameTurnId == myPhone;

    List<Widget> maskedLetters = [];
    bool isFullyGuessed = true;
    for (int i = 0; i < _wordToGuess.length; i++) {
      final char = _wordToGuess[i];
      final isGuessed = _guessedLetters.contains(char);
      if (!isGuessed) isFullyGuessed = false;
      maskedLetters.add(_buildLetterBlock(isGuessed ? char : '_'));
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.tealAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  "Shared Score: $_wordGuesserScore",
                  style: const TextStyle(color: AppTheme.tealAccent, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(LucideIcons.logOut, color: AppTheme.coralAction, size: 24),
                onPressed: _exitGame,
                tooltip: "Quit Game",
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          Text(
            "CLUE: $_wordClue",
            textAlign: TextAlign.center,
            style: TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          Wrap(
            spacing: 4,
            children: maskedLetters,
          ),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            decoration: BoxDecoration(
              color: isMyTurn ? AppTheme.tealAccent.withOpacity(0.15) : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isMyTurn ? "👉 Your Turn: Guess a Letter!" : "⏳ Partner's Turn: Waiting...",
              style: TextStyle(
                color: isMyTurn ? AppTheme.tealAccent : textSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 12),

          Expanded(
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: "ABCDEFGHIJKLMNOPQRSTUVWXYZ".split("").map((letter) {
                  final isAlreadyGuessed = _guessedLetters.contains(letter);
                  return SizedBox(
                    width: 32,
                    height: 38,
                    child: ElevatedButton(
                      onPressed: (!isMyTurn || isAlreadyGuessed || isFullyGuessed) ? null : () => _guessLetter(letter),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        backgroundColor: isAlreadyGuessed ? Colors.grey.withOpacity(0.1) : AppTheme.tealAccent,
                        disabledBackgroundColor: Colors.grey.withOpacity(0.12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(
                        letter,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isAlreadyGuessed ? Colors.grey : Colors.white,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          
          if (isFullyGuessed) ...[
            const SizedBox(height: 8),
            Text("🎉 Puzzle Solved! Excellent Teamwork!", style: TextStyle(color: AppTheme.emeraldGreen, fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 4),
            TextButton(onPressed: _startWordGuesser, child: const Text("Next Puzzle", style: TextStyle(color: AppTheme.tealAccent, fontWeight: FontWeight.bold))),
          ]
        ],
      ),
    );
  }

  Widget _buildTriviaGameWidget(Color textPrimary, Color textSecondary) {
    final myPhone = context.read<AuthProvider>().appUser?.phoneNumber ?? "";
    final partnerPhone = widget.partner.phoneNumber;

    final question = _triviaDataset[_triviaIndex];
    final options = List<String>.from(question['options']);
    
    final bool iHaveAnswered = _triviaAnswers.containsKey(myPhone);
    final bool partnerHasAnswered = _triviaAnswers.containsKey(partnerPhone);
    final bool bothAnswered = iHaveAnswered && partnerHasAnswered;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Score: Me ($_myScore) | Peer ($_partnerScore)",
                style: const TextStyle(color: AppTheme.amberPremium, fontWeight: FontWeight.bold, fontSize: 11),
              ),
              IconButton(
                icon: const Icon(LucideIcons.logOut, color: AppTheme.coralAction, size: 24),
                onPressed: _exitGame,
                tooltip: "Quit Game",
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "Question ${_triviaIndex + 1}/${_triviaDataset.length}",
            style: TextStyle(color: textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  question['question'],
                  textAlign: TextAlign.center,
                  style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 16),
                
                ...List.generate(options.length, (index) {
                  final optionText = options[index];
                  final isSelectedByMe = _triviaAnswers[myPhone] == index;
                  final isSelectedByPartner = _triviaAnswers[partnerPhone] == index;
                  
                  Color cardBorderColor = AppTheme.getBorderColor(context);
                  Color cardBgColor = Colors.transparent;

                  if (bothAnswered) {
                    final correctIndex = question['answer'];
                    if (index == correctIndex) {
                      cardBorderColor = AppTheme.emeraldGreen;
                      cardBgColor = AppTheme.emeraldGreen.withOpacity(0.1);
                    } else if (isSelectedByMe) {
                      cardBorderColor = AppTheme.errorRed;
                      cardBgColor = AppTheme.errorRed.withOpacity(0.1);
                    }
                  } else if (isSelectedByMe) {
                    cardBorderColor = AppTheme.amberPremium;
                    cardBgColor = AppTheme.amberPremium.withOpacity(0.08);
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: InkWell(
                      onTap: iHaveAnswered ? null : () => _submitTriviaAnswer(index),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: cardBgColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: cardBorderColor, width: 1.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                optionText,
                                style: TextStyle(
                                  color: textPrimary,
                                  fontWeight: (isSelectedByMe || isSelectedByPartner) ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                if (isSelectedByMe)
                                  const Icon(LucideIcons.user, size: 14, color: AppTheme.amberPremium),
                                if (isSelectedByPartner)
                                  const Icon(LucideIcons.users, size: 14, color: Colors.blueAccent),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          
          if (bothAnswered) ...[
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _nextTriviaQuestion,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.amberPremium,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                _triviaIndex >= _triviaDataset.length - 1 ? "Complete Quiz" : "Next Question",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ] else if (iHaveAnswered) ...[
            const SizedBox(height: 12),
            Text(
              "Waiting for partner response...",
              style: TextStyle(color: textSecondary, fontStyle: FontStyle.italic, fontSize: 12),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildLetterBlock(String letter) {
    final textPrimary = AppTheme.getTextColor(context);
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    final borderColor = AppTheme.getBorderColor(context);

    return Container(
      width: 28,
      height: 36,
      decoration: BoxDecoration(
        color: scaffoldBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: letter == '_' ? borderColor : AppTheme.tealAccent),
      ),
      child: Center(
        child: Text(
          letter,
          style: TextStyle(
            color: letter == '_' ? textPrimary : AppTheme.tealAccent,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
    double size = 56,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle, 
          color: bgColor, 
          boxShadow: const [
            BoxShadow(
              color: Colors.black12, 
              blurRadius: 8, 
              offset: Offset(0, 3),
            )
          ],
        ),
        child: Icon(icon, color: color, size: size * 0.4),
      ),
    );
  }
}