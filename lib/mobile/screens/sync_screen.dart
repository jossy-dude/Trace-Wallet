import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/services/sync_client_service.dart';

class SyncScreen extends StatefulWidget {
  const SyncScreen({super.key});

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final TextEditingController _ipController = TextEditingController();
  String _statusMessage = "Ready to Sync";
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [Permission.sms, Permission.phone].request();
  }

  Future<void> _handleSync() async {
    if (_ipController.text.isEmpty) {
      setState(() => _statusMessage = "Error: Please enter PC IP Address");
      return;
    }

    setState(() {
      _isSyncing = true;
      _statusMessage = "Syncing with ${_ipController.text}...";
    });

    final result = await SyncClientService().syncUnapprovedTransactions(_ipController.text);

    setState(() {
      _isSyncing = false;
      _statusMessage = result['message'];
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vault Sync Bridge'),
        backgroundColor: Colors.transparent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.phone_android, color: Colors.blue),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Client Mode (Mobile Sensors)',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(_statusMessage, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(
                labelText: 'Target PC IP Address',
                hintText: 'e.g., 192.168.1.XX',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.wifi),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isSyncing ? null : _handleSync,
              icon: _isSyncing
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.sync_alt),
              label: const Text('Sync Transactions to PC'),
            ),
          ],
        ),
      ),
    );
  }
}
