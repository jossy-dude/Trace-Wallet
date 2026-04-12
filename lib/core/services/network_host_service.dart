import 'dart:convert';
import 'dart:io';
import 'package:isar/isar.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'database_service.dart';
import '../models/vault_transaction.dart';
import '../models/paired_device.dart';
import 'package:crypto/hashlib.dart'; // Ensure you have crypto package or similar
import 'package:uuid/uuid.dart';

import '../services/regex_parser_service.dart';
import '../services/alias_service.dart';

class NetworkHostService {
  static final NetworkHostService _instance = NetworkHostService._internal();
  factory NetworkHostService() => _instance;
  NetworkHostService._internal();

  HttpServer? _server;
  final _databaseService = DatabaseService();
  final _parser = RegexParserService();
  final _aliasService = AliasService();

  // Batch Processing State
  final List<VaultTransaction> _syncBuffer = [];
  DateTime? _lastSyncTime;
  static const Duration _syncCooldown = Duration(minutes: 10);

  Middleware _batchProcessingMiddleware(Handler innerHandler) {
    return (Request request) async {
      if (request.url.path == 'sync/transactions' && request.method == 'POST') {
        final now = DateTime.now();
        if (_lastSyncTime != null && now.difference(_lastSyncTime!) < _syncCooldown) {
          // Buffering Mode
          final payload = await request.readAsString();
          final List<dynamic> jsonList = jsonDecode(payload);
          final List<VaultTransaction> incoming = jsonList
              .map((json) => VaultTransaction.fromJson(json as Map<String, dynamic>))
              .toList();
          
          _syncBuffer.addAll(incoming);
          print('Vault: Buffering ${incoming.length} transactions (Cooldown active). Buffer size: ${_syncBuffer.length}');
          
          return Response.ok(jsonEncode({
            'status': 'buffered', 
            'message': 'Cooldown active. Transactions queued for batch processing.',
            'buffer_count': _syncBuffer.length
          }));
        }
        _lastSyncTime = now;
      }
      return await innerHandler(request);
    };
  }

  Future<void> startServer() async {
    // Only run the server if we are on Windows
    if (!Platform.isWindows) return;

    final router = Router();

    // Endpoints
    router.post('/sync/transactions', _syncTransactionsHandler);
    router.post('/p2p/handshake', _p2pHandshakeHandler);
    router.post('/p2p/sync', _p2pSyncHandler);

    // Pipeline: Add Logging and JSON support
      final handler = const Pipeline()
          .addMiddleware(logRequests())
          .addMiddleware(_batchProcessingMiddleware) // Add 10-minute cooldown logic
          .addHandler(router.call);

    try {
      // Listen on port 8080 across all local network interfaces
      _server = await io.serve(handler, InternetAddress.anyIPv4, 8080);
      print('Vault Server successfully activated on: ${_server!.address.address}:${_server!.port}');
    } catch (e) {
      if (e.toString().contains('Address already in use')) {
        print('Port 8080 is already in use; sync server not started.');
      } else {
        print('Vault sync server failed to start: $e');
      }
    }
  }

  Future<Response> _p2pHandshakeHandler(Request request) async {
    final payload = jsonDecode(await request.readAsString());
    final remoteId = payload['device_id'];
    final remoteName = payload['name'];
    
    // Store as pending or trusted
    final isar = _databaseService.isar;
    final device = PairedDevice()
      ..deviceId = remoteId
      ..name = remoteName
      ..addedAt = DateTime.now()
      ..isTrusted = false // Require manual trust in UI
      ..deviceType = remoteId.toString().contains('MOBILE') ? 'mobile' : 'desktop';
      
    await isar.writeTxn(() => isar.pairedDevices.put(device));
    
    return Response.ok(jsonEncode({
      'status': 'waiting_for_approval',
      'local_id': await _getOrCreateDeviceId(),
      'local_name': Platform.localHostname
    }));
  }

  Future<Response> _p2pSyncHandler(Request request) async {
    final deviceId = request.headers['X-Vault-Device-ID'];
    final isar = _databaseService.isar;
    
    final device = await isar.pairedDevices.filter().deviceIdEqualTo(deviceId).findFirst();
    if (device == null || !device.isTrusted) {
      return Response.forbidden(jsonEncode({'status': 'error', 'message': 'Device not trusted'}));
    }
    
    final payload = jsonDecode(await request.readAsString());
    final transactions = payload['transactions'] as List?;
    
    if (transactions != null) {
      // Process incoming transactions (delta sync)
      // ... similar to _syncTransactionsHandler but specifically for P2P
    }
    
    return Response.ok(jsonEncode({'status': 'success'}));
  }

  Future<String> _getOrCreateDeviceId() async {
    // For now, simple UUID stored in local file or database
    return const Uuid().v4().substring(0, 16).toUpperCase();
  }

  Future<Response> _syncTransactionsHandler(Request request) async {
    try {
      final String payload = await request.readAsString();
      final List<dynamic> jsonList = jsonDecode(payload);

      final List<VaultTransaction> incoming = jsonList
          .map((json) => VaultTransaction.fromJson(json as Map<String, dynamic>))
          .toList();

      final List<VaultTransaction> rawTransactions = [..._syncBuffer, ...incoming];
      _syncBuffer.clear(); // Flush buffer into current batch

      final isar = _databaseService.isar;

      // Sort incoming by date to process in chronological order
      rawTransactions.sort((a, b) => a.date.compareTo(b.date));

      final List<VaultTransaction> finalBatch = [];

      for (var tx in rawTransactions) {
        // Handshake / Deduplication Logic: Check if transaction already exists
        // Uses rawText + date as a unique signature
        final existing = await isar.vaultTransactions
            .filter()
            .rawTextEqualTo(tx.rawText)
            .dateEqualTo(tx.date)
            .findFirst();
        
        if (existing != null) {
          print('Vault: Skipping duplicate transaction from log handshake.');
          continue;
        }

        // Step 1: Extract Amount & Balance (Transform)
        var processed = _parser.processRawTransaction(tx);
        
        // Step 2: Date Filtering (Ignore old SMS)
        if (_parser.shouldIgnore(processed.category, processed.date)) {
          continue;
        }

        // Step 3: Map to Alias (Transform)
        processed = await _aliasService.mapTransactionToPerson(processed);
        
        // Approval Queue Logic: Always set status to pending_approval unless verified
        // (Do not auto-add to ledger without manual verification step)
        processed.isApproved = false;
        if (processed.category == 'Requires Review') {
          processed.isApproved = false;
        }
        
        // Step 4: Reconciliation (Ghost Fee Logic)
        if (processed.balance != null && processed.category != null && processed.category != 'Requires Review') {
          // Find the last known transaction for this bank in the database
          final lastTx = await isar.vaultTransactions
              .where()
              .categoryEqualTo(processed.category!)
              .sortByDateDesc()
              .findFirst();

          if (lastTx != null && lastTx.balance != null) {
            double prevBal = lastTx.balance!;
            double currentBal = processed.balance!;
            double amount = processed.amount ?? 0.0;
            double fee = processed.fee ?? 0.0;
            
            // Logic: Is (Prev - Current) == (Amount + Fee)?
            // (Assuming Expense for simplicity, adjust for Income)
            bool isIncome = processed.rawText.toLowerCase().contains('received') || processed.rawText.toLowerCase().contains('credited');
            
            double expectedChange = isIncome ? amount : (amount + fee);
            double actualDiff = isIncome ? (currentBal - prevBal) : (prevBal - currentBal);
            
            double gap = actualDiff - expectedChange;
            
            if (gap.abs() > 0.5) {
              // Create Ghost Transaction
              final ghost = VaultTransaction(
                rawText: "System: Calculated hidden fee / adjustment",
                amount: gap.abs(),
                date: processed.date.subtract(const Duration(seconds: 1)),
                senderAlias: "System Audit",
                category: "GHOST_ADJUST",
                aiSummary: "Detected discrepancy of ${gap.abs().toStringAsFixed(2)} ETB",
                isApproved: true,
              );
              finalBatch.add(ghost);
            }
          }
        }
        
        finalBatch.add(processed..id = Isar.autoIncrement);
      }

      // Save final batch to Windows Isar database (Load)
      await isar.writeTxn(() async {
        for (var tx in finalBatch) {
          await isar.vaultTransactions.put(tx);
        }
      });

      return Response.ok(jsonEncode({'status': 'success', 'count': finalBatch.length}));
    } catch (e) {
      return Response.internalServerError(body: 'Sync failed: $e');
    }
  }

  Future<void> stopServer() async {
    await _server?.close();
  }
}
