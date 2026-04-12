import 'dart:convert';
import 'dart:io';
import 'package:isar/isar.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'database_service.dart';
import '../models/vault_transaction.dart';

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

  Future<void> startServer() async {
    // Only run the server if we are on Windows
    if (!Platform.isWindows) return;

    final router = Router();

    // Endpoints
    router.post('/sync/transactions', _syncTransactionsHandler);

    // Pipeline: Add Logging and JSON support
    final handler = const Pipeline()
        .addMiddleware(logRequests())
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

  Future<Response> _syncTransactionsHandler(Request request) async {
    try {
      final String payload = await request.readAsString();
      final List<dynamic> jsonList = jsonDecode(payload);

      final List<VaultTransaction> rawTransactions = jsonList
          .map((json) => VaultTransaction.fromJson(json as Map<String, dynamic>))
          .toList();

      final isar = _databaseService.isar;

      // Sort incoming by date to process in chronological order
      rawTransactions.sort((a, b) => a.date.compareTo(b.date));

      final List<VaultTransaction> finalBatch = [];

      for (var tx in rawTransactions) {
        // Step 1: Extract Amount & Balance (Transform)
        var processed = _parser.processRawTransaction(tx);
        
        // Step 2: Date Filtering (Ignore old SMS)
        if (_parser.shouldIgnore(processed.category, processed.date)) {
          continue;
        }

        // Step 3: Map to Alias (Transform)
        processed = await _aliasService.mapTransactionToPerson(processed);
        
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
