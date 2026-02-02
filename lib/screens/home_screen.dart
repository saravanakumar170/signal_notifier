import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/signal_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _storage = StorageService.instance;
  final _signalManager = SignalManager.instance;
  
  bool _notificationsEnabled = true;
  String? _lastSignal;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  void _loadState() {
    setState(() {
      _notificationsEnabled = _storage.notificationEnabled;
      _lastSignal = _storage.lastSignalType;
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    await _storage.setNotificationEnabled(value);
    setState(() {
      _notificationsEnabled = value;
    });
    
    _showSnackBar(
      value ? 'Notifications enabled ✓' : 'Notifications disabled',
      value ? Colors.green : Colors.orange,
    );
  }

  Future<void> _sendSignal(String signalType, {bool isTest = true}) async {
    final success = await _signalManager.sendSignal(signalType, isTest: isTest);
    
    if (success) {
      setState(() {
        _lastSignal = signalType;
      });
      _showSnackBar(
        isTest ? 'Test signal sent: $signalType ✓' : 'Signal sent: $signalType ✓',
        Colors.green,
      );
    } else {
      String reason = '';
      if (!_notificationsEnabled) {
        reason = 'Notifications are disabled';
      } else {
        reason = 'Unknown error';
      }
      
      _showSnackBar(
        'Signal blocked: $reason',
        Colors.red,
      );
    }
  }

  Future<void> _clearLastSignal() async {
    await _signalManager.clearLastSignal();
    setState(() {
      _lastSignal = null;
    });
    _showSnackBar(
      'Last signal cleared ✓',
      Colors.blue,
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Smart Signal Notifier',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        _notificationsEnabled
                            ? Icons.notifications_active
                            : Icons.notifications_off,
                        size: 48,
                        color: _notificationsEnabled
                            ? Colors.green
                            : Colors.grey,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _notificationsEnabled
                            ? 'Notifications Active'
                            : 'Notifications Disabled',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _notificationsEnabled
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                      ),
                      const SizedBox(height: 20),
                      SwitchListTile(
                        value: _notificationsEnabled,
                        onChanged: _toggleNotifications,
                        title: const Text('Enable Notifications'),
                        subtitle: const Text('Toggle to control signal alerts'),
                        activeTrackColor: Colors.green,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Last Signal Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.history, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Last Signal',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _lastSignal != null
                              ? Colors.blue.shade50
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _lastSignal != null
                                ? Colors.blue.shade200
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Text(
                          _lastSignal ?? 'No signal sent yet',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _lastSignal != null
                                ? Colors.blue.shade900
                                : Colors.grey.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Test Buttons Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.science, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Test Signals',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildSignalButton(
                        'BUY',
                        Colors.green,
                        Icons.trending_up,
                      ),
                      const SizedBox(height: 12),
                      _buildSignalButton(
                        'SELL',
                        Colors.red,
                        Icons.trending_down,
                      ),
                      const SizedBox(height: 12),
                      _buildSignalButton(
                        'NO ENTRY',
                        Colors.orange,
                        Icons.block,
                      ),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed: _clearLastSignal,
                        icon: const Icon(Icons.clear_all),
                        label: const Text(
                          'Clear Last Signal',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          side: const BorderSide(color: Colors.blue, width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Info Card
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700),
                          const SizedBox(width: 8),
                          Text(
                            'How it works',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• Only unique signal changes trigger notifications\n'
                        '• Duplicate signals are automatically blocked\n'
                        '• No daily limit - unlimited unique signals\n'
                        '• Memory resets daily at 9:17 AM',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.blue.shade800,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSignalButton(String signal, Color color, IconData icon) {
    return ElevatedButton.icon(
      onPressed: () => _sendSignal(signal),
      icon: Icon(icon, size: 24),
      label: Text(
        'Send $signal Signal',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: 2,
      ),
    );
  }
}
