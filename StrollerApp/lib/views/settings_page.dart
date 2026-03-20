import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_state.dart';
import '../services/wifi_service.dart';

/// Settings page - controls Raspberry Pi ↔ ESP32S3 configuration
///
/// - Phone app -> Raspberry Pi (/update_config)
/// - Raspberry Pi -> ESP32S3 (/config and /data)
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final WifiService _wifiService = WifiService();
  final TextEditingController _frequencyController = TextEditingController();
  final TextEditingController _fieldsController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  Map<String, dynamic>? _status;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _frequencyController.dispose();
    _fieldsController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final appState = context.read<MyAppState>();
    final wifiState = appState.wifiState;

    if (!wifiState.isConnected || wifiState.deviceIp == null) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Not connected to SmartStroller WiFi.\nPlease connect on the Connection page first.';
      });
      return;
    }

    _wifiService.setDeviceIp(wifiState.deviceIp!);

    final status = await _wifiService.fetchServerStatus();
    if (!mounted) return;

    if (status == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load server status from Raspberry Pi.';
      });
      return;
    }

    final currentConfig =
        (status['current_config'] as Map?)?.cast<String, dynamic>() ?? {};

    final freq = currentConfig['frequency'];
    final dataFields = currentConfig['dataFields'] ?? 'all';

    _frequencyController.text =
        freq != null ? freq.toString() : '500'; // default 500ms
    _fieldsController.text = dataFields.toString();

    setState(() {
      _status = status;
      _isLoading = false;
    });
  }

  Future<void> _saveConfig() async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    int? freq;
    final freqText = _frequencyController.text.trim();
    if (freqText.isNotEmpty) {
      freq = int.tryParse(freqText);
      if (freq == null || freq <= 0) {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Frequency must be a positive number (milliseconds).';
        });
        return;
      }
    }

    final dataFields = _fieldsController.text.trim().isEmpty
        ? 'all'
        : _fieldsController.text.trim();

    final success = await _wifiService.updateServerConfig(
      dataFields: dataFields,
      frequency: freq,
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Configuration updated successfully')),
      );
      await _loadStatus();
    } else {
      setState(() {
        _errorMessage = 'Failed to update configuration on Raspberry Pi.';
      });
    }

    setState(() {
      _isSaving = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SmartStroller Settings')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_errorMessage != null) ...[
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
                    const SizedBox(height: 16),
                  ],

                  // Status card
                  if (_status != null) _buildStatusCard(_status!),

                  const SizedBox(height: 24),

                  // Configuration form
                  Card(
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ESP32 Data Configuration',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _frequencyController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Sampling Frequency (ms)',
                              hintText: 'e.g. 500',
                              helperText:
                                  'How often ESP32 sends data (min 100ms).',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _fieldsController,
                            decoration: const InputDecoration(
                              labelText: 'Data Fields',
                              hintText:
                                  'all or comma separated (temperature,humidity,roll,pitch,yaw,raindrop,sunshine)',
                              helperText:
                                  'Controls which fields ESP32 includes in JSON.',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _isSaving ? null : _saveConfig,
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.save),
                              label: Text(
                                  _isSaving ? 'Saving...' : 'Save Configuration'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusCard(Map<String, dynamic> status) {
    final statistics =
        (status['statistics'] as Map?)?.cast<String, dynamic>() ?? {};
    final config =
        (status['current_config'] as Map?)?.cast<String, dynamic>() ?? {};

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Raspberry Pi Status',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildStatusRow('AP SSID', status['ap_ssid'] ?? 'SmartStroller'),
            _buildStatusRow('AP IP', status['ap_ip'] ?? '192.168.4.1'),
            _buildStatusRow('Total Readings',
                (statistics['total_readings'] ?? 0).toString()),
            _buildStatusRow(
                'Last Received', statistics['last_received'] ?? 'Never'),
            const SizedBox(height: 8),
            const Text(
              'Current ESP32 Config',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            _buildStatusRow(
                'Data Format', config['dataFormat']?.toString() ?? 'json'),
            _buildStatusRow(
                'Data Fields', config['dataFields']?.toString() ?? 'all'),
            _buildStatusRow(
                'Frequency (ms)', config['frequency']?.toString() ?? '500'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                value,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500),
                textAlign: TextAlign.right,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
