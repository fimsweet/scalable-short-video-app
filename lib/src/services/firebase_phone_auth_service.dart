import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Service for handling Firebase Phone Authentication
class FirebasePhoneAuthService extends ChangeNotifier {
  static final FirebasePhoneAuthService _instance = FirebasePhoneAuthService._internal();
  factory FirebasePhoneAuthService() => _instance;
  FirebasePhoneAuthService._internal();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  String? _verificationId;
  int? _resendToken;
  bool _isLoading = false;
  String? _errorMessage;
  
  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasVerificationId => _verificationId != null;
  
  /// Send OTP to phone number
  /// Returns true if OTP was sent successfully
  Future<bool> sendOtp(String phoneNumber) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    final completer = Completer<bool>();
    
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        forceResendingToken: _resendToken,
        
        // Called when verification is completed automatically (auto-retrieve on Android)
        verificationCompleted: (PhoneAuthCredential credential) async {
          print('📱 Auto-verification completed');
          // Auto sign-in (Android only)
          try {
            await _auth.signInWithCredential(credential);
            _isLoading = false;
            notifyListeners();
            if (!completer.isCompleted) completer.complete(true);
          } catch (e) {
            print('❌ Auto sign-in failed: $e');
            _errorMessage = 'Auto sign-in failed';
            _isLoading = false;
            notifyListeners();
            if (!completer.isCompleted) completer.complete(false);
          }
        },
        
        // Called when verification fails
        verificationFailed: (FirebaseAuthException e) {
          print('❌ Verification failed: ${e.message}');
          _errorMessage = _getErrorMessage(e.code);
          _isLoading = false;
          notifyListeners();
          if (!completer.isCompleted) completer.complete(false);
        },
        
        // Called when OTP is sent successfully
        codeSent: (String verificationId, int? resendToken) {
          print('📱 OTP sent! Verification ID: $verificationId');
          _verificationId = verificationId;
          _resendToken = resendToken;
          _isLoading = false;
          notifyListeners();
          if (!completer.isCompleted) completer.complete(true);
        },
        
        // Called when auto-retrieval timeout
        codeAutoRetrievalTimeout: (String verificationId) {
          print('⏰ Auto-retrieval timeout');
          _verificationId = verificationId;
        },
      );
      
      return completer.future;
    } catch (e) {
      print('❌ Send OTP error: $e');
      _errorMessage = 'Failed to send OTP. Please try again.';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  /// Verify OTP and sign in
  /// Returns the Firebase ID token if successful, null otherwise
  Future<String?> verifyOtp(String smsCode) async {
    if (_verificationId == null) {
      _errorMessage = 'Please request OTP first';
      notifyListeners();
      return null;
    }
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    
    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: smsCode,
      );
      
      final userCredential = await _auth.signInWithCredential(credential);
      final idToken = await userCredential.user?.getIdToken();
      
      print('✅ Phone auth successful! UID: ${userCredential.user?.uid}');
      
      _isLoading = false;
      notifyListeners();
      
      return idToken;
    } on FirebaseAuthException catch (e) {
      print('❌ Verify OTP error: ${e.code} - ${e.message}');
      _errorMessage = _getErrorMessage(e.code);
      _isLoading = false;
      notifyListeners();
      return null;
    } catch (e) {
      print('❌ Verify OTP error: $e');
      _errorMessage = 'Failed to verify OTP. Please try again.';
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }
  
  /// Get current user's ID token (for backend verification)
  Future<String?> getIdToken() async {
    try {
      return await _auth.currentUser?.getIdToken();
    } catch (e) {
      print('❌ Get ID token error: $e');
      return null;
    }
  }
  
  /// Sign out from Firebase Auth
  Future<void> signOut() async {
    await _auth.signOut();
    _verificationId = null;
    _resendToken = null;
    notifyListeners();
  }
  
  /// Reset state (call when navigating away)
  void reset() {
    _verificationId = null;
    _resendToken = null;
    _isLoading = false;
    _errorMessage = null;
    notifyListeners();
  }
  
  /// Convert Firebase error codes to user-friendly messages
  String _getErrorMessage(String code) {
    switch (code) {
      case 'invalid-phone-number':
        return 'Invalid phone number format';
      case 'too-many-requests':
        return 'Too many requests. Please try again later';
      case 'invalid-verification-code':
        return 'Invalid OTP code';
      case 'session-expired':
        return 'OTP expired. Please request a new one';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Please try again later';
      default:
        return 'An error occurred. Please try again';
    }
  }
}
