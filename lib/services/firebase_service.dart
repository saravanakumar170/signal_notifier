import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/signal_model.dart';
import 'signal_manager.dart';

class FirebaseService {
  static final FirebaseService instance = FirebaseService._internal();
  factory FirebaseService() => instance;
  FirebaseService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final _signalManager = SignalManager.instance;
  
  bool _isListening = false;
  String? _lastProcessedSignal;
  DateTime? _lastSignalTime;

  /// Start listening to Firebase signals collection
  void startListening() {
    if (_isListening) {
      debugPrint('Firebase listener already active');
      return;
    }

    _isListening = true;
    debugPrint('Starting Firebase listener...');

    // Listen to the most recent signal
    _firestore
        .collection('signals')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen(
      (snapshot) {
        if (snapshot.docs.isEmpty) {
          debugPrint('No signals in Firebase yet');
          return;
        }

        final doc = snapshot.docs.first;
        final signal = SignalModel.fromFirestore(doc.data());

        debugPrint('Firebase signal received: ${signal.type} at ${signal.timestamp}');

        // Process the signal
        _processSignal(signal);
      },
      onError: (error) {
        debugPrint('Firebase listener error: $error');
      },
    );
  }

  /// Process incoming Firebase signal
  void _processSignal(SignalModel signal) {
    // Update last processed signal for tracking
    _lastProcessedSignal = signal.type;
    _lastSignalTime = signal.timestamp;

    debugPrint('Processing Firebase signal: ${signal.type}');

    // Send to SignalManager (which handles duplicate blocking and notifications)
    // Pass isTest=false since these are live signals from Firebase
    _signalManager.sendSignal(signal.type, isTest: false);
  }

  /// Stop listening (for cleanup)
  void stopListening() {
    _isListening = false;
    debugPrint('Firebase listener stopped');
  }

  /// Get connection status
  bool get isConnected => _isListening;

  /// Get last signal info
  String? get lastSignal => _lastProcessedSignal;
  DateTime? get lastSignalTime => _lastSignalTime;
}
