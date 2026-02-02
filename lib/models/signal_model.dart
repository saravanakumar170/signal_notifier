class SignalModel {
  final String type; // "BUY", "SELL", "NO ENTRY"
  final DateTime timestamp;
  final String source;
  
  SignalModel({
    required this.type,
    required this.timestamp,
    required this.source,
  });
  
  // Create from Firestore document
  factory SignalModel.fromFirestore(Map<String, dynamic> data) {
    return SignalModel(
      type: data['type'] ?? 'NO ENTRY',
      timestamp: data['timestamp'] != null 
          ? (data['timestamp'] as dynamic).toDate()
          : DateTime.now(),
      source: data['source'] ?? 'unknown',
    );
  }
  
  // Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'type': type,
      'timestamp': timestamp,
      'source': source,
    };
  }
}
