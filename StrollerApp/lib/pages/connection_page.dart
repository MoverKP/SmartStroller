import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../services/wifi_service.dart';

/// Connection page - WiFi connection to Raspberry Pi SmartStroller AP
class ConnectionPage extends StatefulWidget {
  const ConnectionPage({super.key});

  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  final WifiService _wifiService = WifiService();
  final TextEditingController _ipController = TextEditingController(
    text: WifiService.defaultIp,
  );
  bool _isConnecting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkCurrentConnection();
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  /// Check if already connected
  void _checkCurrentConnection() {
    final appState = context.read<MyAppState>();
    if (appState.wifiState.isConnected && appState.wifiState.deviceIp != null) {
      _ipController.text = appState.wifiState.deviceIp!;
    }
  }

  /// Connect to ESP32 device
  Future<void> _connectToDevice() async {
    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    final ip = _ipController.text.trim();
    if (ip.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter an IP address';
        _isConnecting = false;
      });
      return;
    }

    // Validate IP format (basic check)
    final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
    if (!ipRegex.hasMatch(ip)) {
      setState(() {
        _errorMessage = 'Invalid IP address format';
        _isConnecting = false;
      });
      return;
    }

    try {
      final connected = await _wifiService.testConnection(ip: ip);
      
      if (connected) {
        final appState = context.read<MyAppState>();
        appState.wifiState.setConnected(
          true,
          deviceIp: ip,
          deviceName: 'SmartStroller Server',
        );
        
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Connected to device successfully')),
          );
        }
      } else {
        setState(() {
          _errorMessage = 'Failed to connect. Please check:\n'
              '• Device is powered on\n'
              '• Phone is connected to "Stroller_Device" WiFi\n'
              '• IP address is correct';
          _isConnecting = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection error: $e';
        _isConnecting = false;
      });
    }
  }

  /// Disconnect from device
  void _disconnect() {
    _wifiService.disconnect();
    final appState = context.read<MyAppState>();
    appState.wifiState.disconnect();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Disconnected')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<MyAppState>();
    final wifiState = appState.wifiState;

    return Scaffold(
      appBar: AppBar(
        title: const Text('WiFi Connection'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Connection Status Card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(
                      wifiState.isConnected
                          ? Icons.wifi
                          : Icons.wifi_off,
                      size: 48,
                      color: wifiState.isConnected ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      wifiState.isConnected ? 'Connected' : 'Not Connected',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: wifiState.isConnected ? Colors.green : Colors.grey,
                      ),
                    ),
                    if (wifiState.isConnected && wifiState.deviceIp != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Device IP: ${wifiState.deviceIp}',
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Instructions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Connection Instructions',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    _buildInstructionStep(
                      '1',
                      'Connect your phone to WiFi network:',
                      'SSID: SmartStroller\n(No password by default)',
                    ),
                    const SizedBox(height: 8),
                    _buildInstructionStep(
                      '2',
                      'Enter the device IP address:',
                      'Default: 192.168.4.1\n(Check ESP32 Serial Monitor)',
                    ),
                    const SizedBox(height: 8),
                    _buildInstructionStep(
                      '3',
                      'Tap "Connect" to establish connection',
                      '',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // IP Address Input
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: 'Device IP Address',
                hintText: '192.168.4.1',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.computer),
              ),
              keyboardType: TextInputType.number,
              enabled: !_isConnecting && !wifiState.isConnected,
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red[700]),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Connect/Disconnect Button
            if (wifiState.isConnected)
              ElevatedButton.icon(
                onPressed: _isConnecting ? null : _disconnect,
                icon: const Icon(Icons.wifi_off),
                label: const Text('Disconnect'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              )
            else
              ElevatedButton.icon(
                onPressed: _isConnecting ? null : _connectToDevice,
                icon: _isConnecting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.wifi),
                label: Text(_isConnecting ? 'Connecting...' : 'Connect'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionStep(String number, String title, String details) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              if (details.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  details,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
