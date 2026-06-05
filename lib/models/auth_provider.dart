import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../services/firestore_service.dart';
import 'models.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'talktandem');
  final FirestoreService firestore = FirestoreService();

  User? _user;
  Map<String, dynamic>? _userData;
  bool _isLoading = false;
  bool _isRegistering = false; // Tracks if the user is currently in the active registration form
  StreamSubscription<DocumentSnapshot>? _userDocSubscription;

  AuthProvider() {
    _isLoading = true;
    print("[TalkTandem AuthProvider] Initializing AuthProvider...");
    
    // Listen to authentication state changes
    _auth.authStateChanges().listen((User? user) async {
      print("[TalkTandem AuthProvider] authStateChanges fired. User: ${user?.uid ?? 'NULL (Signed Out)'}");
      
      // Cancel previous subscription first
      _userDocSubscription?.cancel();
      _userDocSubscription = null;
      
      _user = user;
      
      if (user != null) { 
        // Since we are strictly using the phone number as the document ID, we get the verified phone number
        final phone = user.phoneNumber;
        
        if (phone != null && phone.isNotEmpty) {
          print("[TalkTandem AuthProvider] Active session detected. Initializing real-time profile listener for phone: $phone");
          
          _userDocSubscription = _db.collection('users').doc(phone).snapshots().listen((doc) async {
            if (doc.exists) {
              _userData = doc.data();
              print("[TalkTandem AuthProvider] Real-time profile update: ${_userData?['name']}, XP: ${_userData?['xp']}");
              _isLoading = false;
              notifyListeners();
            } else {
              print("[TalkTandem AuthProvider] Real-time profile check: document does not exist yet under phone: $phone.");
              _userData = null;
              
              // Auto-clean if not in active registration form
              if (!_isRegistering) {
                print("[TalkTandem AuthProvider] Profile document not found in Firestore and NOT in active registration. Auto-cleaning incomplete session...");
                _userDocSubscription?.cancel();
                _userDocSubscription = null;
                await _auth.signOut();
                _user = null;
                _userData = null;
              }
              _isLoading = false;
              notifyListeners();
            }
          }, onError: (e) {
            print("[TalkTandem AuthProvider] ERROR in real-time profile stream: $e");
          });
        } else {
          print("[TalkTandem AuthProvider] Active user logged in but phone number is empty. Waiting for registration/login link.");
          _isLoading = false;
          notifyListeners();
        }
      } else {
        print("[TalkTandem AuthProvider] No active session. Clearing local user data cache.");
        _userData = null;
        _isLoading = false;
        notifyListeners();
      }
    });
  }

  User? get currentUser => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  Map<String, dynamic>? get userData => _userData;
  bool get isRegistering => _isRegistering;
  String? get uid => _user?.uid;

  AppUser? get appUser => _userData != null && _user != null
      ? AppUser.fromMap(_userData!['phoneNumber'] ?? _user!.phoneNumber ?? _user!.uid, _userData!)
      : null;

  static String? inferStateFromLocation(String location) {
    if (location.isEmpty) return null;
    final parts = location.split(',');
    if (parts.length > 1) {
      return parts.last.trim();
    }
    return parts.first.trim();
  }

  void setLoading(bool val) {
    _isLoading = val;
    notifyListeners();
  }

  void setRegistering(bool val) {
    print("[TalkTandem AuthProvider] setRegistering flag updated to: $val");
    _isRegistering = val;
    notifyListeners();
  }

  // Check if a user profile exists in Firestore (checks phone number or UID as fallback query)
  Future<bool> checkUserExists(String identifier) async {
    print("[TalkTandem AuthProvider] Checking if Firestore user document exists for: $identifier");
    try {
      if (identifier.startsWith('+')) {
        final doc = await _db.collection('users').doc(identifier).get();
        return doc.exists;
      } else {
        // Fallback search by UID field using correct Dart Firestore named syntax
        final query = await _db.collection('users').where('uid', isEqualTo: identifier).limit(1).get();
        return query.docs.isNotEmpty;
      }
    } catch (e) {
      print("[TalkTandem AuthProvider] ERROR checking user document in Firestore: $e");
      return false;
    }
  }

  // Load user profile details using phone number or UID fallback
  Future<void> loadUserData(String identifier) async {
    print("[TalkTandem AuthProvider] loadUserData: loading details for identifier: $identifier");
    try {
      String docId = identifier;
      
      // If identifier is not a phone number, resolve it via current authenticated user or query
      if (!identifier.startsWith('+')) {
        final phone = _auth.currentUser?.phoneNumber;
        if (phone != null && phone.isNotEmpty) {
          docId = phone;
        } else {
          // Robust query search by UID field using correct Dart Firestore named syntax
          final query = await _db.collection('users').where('uid', isEqualTo: identifier).limit(1).get();
          if (query.docs.isNotEmpty) {
            _userData = query.docs.first.data();
            print("[TalkTandem AuthProvider] loadUserData SUCCESS via UID query. Username: ${_userData?['name']}");
            notifyListeners();
            return;
          }
        }
      }

      final doc = await _db.collection('users').doc(docId).get();
      if (doc.exists) {
        _userData = doc.data();
        print("[TalkTandem AuthProvider] loadUserData SUCCESS. Username: ${_userData?['name']}, Phone: ${_userData?['phoneNumber']}");
        notifyListeners();
      } else {
        print("[TalkTandem AuthProvider] loadUserData warning: Document not found in Firestore users collection for $docId.");
      }
    } catch (e) {
      print("[TalkTandem AuthProvider] ERROR loading user data from Firestore: $e");
    }
  }

  // Upload a verified camera selfie file to Firebase Storage
  Future<String?> uploadSelfie(String uid, String filePath) async {
    print("[TalkTandem AuthProvider] uploadSelfie initiated for UID: $uid. File path: $filePath");
    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print("[TalkTandem AuthProvider] uploadSelfie error: Captured file does not exist at path!");
        return null;
      }
      
      final ref = FirebaseStorage.instance.ref().child('avatars').child('$uid.jpg');
      print("[TalkTandem AuthProvider] Uploading file to Firebase Storage ref: ${ref.fullPath}");
      await ref.putFile(file);
      final downloadUrl = await ref.getDownloadURL();
      print("[TalkTandem AuthProvider] Upload success. Download URL: $downloadUrl");
      return downloadUrl;
    } catch (e) {
      print("[TalkTandem AuthProvider] ERROR uploading selfie file: $e");
      return null;
    }
  }

  // Register a new user in Firestore under exactly ONE phone number document ID
  Future<void> registerUser({
    required String uid,
    required String name,
    required String dob,
    required String gender,
    required String? location,
    required List<String> interests,
    required bool isSelfieVerified,
    required String phoneNumber,
    required String? avatarUrl, // Verified profile selfie URL
  }) async {
    print("[TalkTandem AuthProvider] registerUser initiated for phone: $phoneNumber");
    setLoading(true);
    try {
      final data = {
        'uid': uid,
        'name': name,
        'dob': dob,
        'gender': gender,
        'location': location ?? '',
        'interests': interests,
        'isSelfieVerified': isSelfieVerified,
        'phoneNumber': phoneNumber,
        'avatarUrl': avatarUrl ?? '', // Dynamic verified avatar URL
        'createdAt': FieldValue.serverTimestamp(),
        'xp': 450, // Initial signup bonus
        'streak': 1,
        'conversationsCount': 0,
        'avgRating': 5.0,
      };
      
      print("[TalkTandem AuthProvider] Writing new user profile data to Firestore strictly under phone Doc ID: $phoneNumber...");
      await _db.collection('users').doc(phoneNumber).set(data);
      
      _userData = data;
      _isRegistering = false; // Registration complete, clear registering flag
      print("[TalkTandem AuthProvider] Firestore profile write SUCCESS. setRegistering reset to false.");
      notifyListeners();
    } catch (e) {
      print("[TalkTandem AuthProvider] ERROR registering user in Firestore: $e");
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  // Live Phone OTP verification
  Future<void> sendOtp(
    String phoneNumber, {
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(FirebaseAuthException e) onVerificationFailed,
  }) async {
    print("[TalkTandem AuthProvider] sendOtp initiated for phone: $phoneNumber");
    setLoading(true);
    try {
      print("[TalkTandem AuthProvider] Calling FirebaseAuth.instance.verifyPhoneNumber...");
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          print("[TalkTandem AuthProvider] verifyPhoneNumber: verificationCompleted callback triggered automatically!");
          try {
            print("[TalkTandem AuthProvider] Auto-signing in with PhoneAuthCredential...");
            await _auth.signInWithCredential(credential);
            print("[TalkTandem AuthProvider] Auto-sign in SUCCESS.");
          } catch (e) {
            print("[TalkTandem AuthProvider] Auto-sign in ERROR: $e");
          }
          setLoading(false);
        },
        verificationFailed: (FirebaseAuthException e) {
          print("[TalkTandem AuthProvider] verifyPhoneNumber: verificationFailed callback triggered! Code: ${e.code}, Message: ${e.message}");
          setLoading(false);
          onVerificationFailed(e);
        },
        codeSent: (String verificationId, int? resendToken) {
          print("[TalkTandem AuthProvider] verifyPhoneNumber: codeSent callback triggered! verificationId: $verificationId, resendToken: $resendToken");
          setLoading(false);
          onCodeSent(verificationId, resendToken);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          print("[TalkTandem AuthProvider] verifyPhoneNumber: codeAutoRetrievalTimeout callback triggered for verificationId: $verificationId");
        },
      );
    } catch (e) {
      setLoading(false);
      print("[TalkTandem AuthProvider] Unexpected ERROR during verifyPhoneNumber call: $e");
    }
  }

  // Confirm verification code
  Future<UserCredential> verifyOtp({
    required String verificationId,
    required String smsCode,
  }) async {
    print("[TalkTandem AuthProvider] verifyOtp called. VerificationId: $verificationId, SmsCode: $smsCode");
    setLoading(true);
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      print("[TalkTandem AuthProvider] Attempting sign-in with Phone OTP Credential...");
      final userCredential = await _auth.signInWithCredential(credential);
      print("[TalkTandem AuthProvider] Sign-in with OTP SUCCESS. UID: ${userCredential.user?.uid}");
      return userCredential;
    } catch (e) {
      print("[TalkTandem AuthProvider] ERROR verifying OTP code: $e");
      rethrow;
    } finally {
      setLoading(false);
    }
  }

  // Logout
  Future<void> logout() async {
    print("[TalkTandem AuthProvider] logout requested.");
    setLoading(true);
    try {
      _userDocSubscription?.cancel();
      _userDocSubscription = null;
      print("[TalkTandem AuthProvider] Calling FirebaseAuth.instance.signOut()...");
      await _auth.signOut();
      _user = null;
      _userData = null;
      _isRegistering = false; // Reset registering flag on manual logout
      print("[TalkTandem AuthProvider] Sign out successful. Cache and flags cleared.");
    } catch (e) {
      print("[TalkTandem AuthProvider] ERROR during signOut: $e");
    } finally {
      setLoading(false);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _userDocSubscription?.cancel();
    super.dispose();
  }
  
}