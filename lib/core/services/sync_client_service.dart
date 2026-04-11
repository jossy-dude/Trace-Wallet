import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:isar/isar.dart';
import 'database_service.dart';
import '../models/vault_transaction.dart';

class SyncClientService {
  static final SyncClientService _instance = SyncClientService._internal();
  factory SyncClientService() => _instance;
  SyncClientService._internal();

  final _databaseService = DatabaseService();

  Future<Map<String, dynamic>> syncUnapprovedTransactions(String targetIp) async {
    try {
      final isar = _databaseService.isar;

      // 1. Find all transactions that haven't been synced/approved yet
      final unapproved = await isar.vaultTransactions
          .filter()
          .isApprovedEqualTo(false)
          .findAll();

      if (unapproved.isEmpty) {
        return {'status': 'info', 'message': 'Nothing to sync.'};
      }

      // 2. Serialize to JSON list
      final List<Map<String, dynamic>> payload = unapproved
          .map((tx) => tx.toJson())
          .toList();

      // 3. POST to the PC Server
      final url = Uri.parse('http://$targetIp:8080/sync/transactions');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // 4. Update local DB: Mark as approved so we don't sync them again
        await isar.writeTxn(() async {
          for (var tx in unapproved) {
            tx.isApproved = true;
            await isar.vaultTransactions.put(tx);
          }
        });

        return {
          'status': 'success',
          'message': 'Synced ${unapproved.length} transactions.'
        };
      } else {
        return {
          'status': 'error',
          'message': 'Server returned error: ${response.statusCode}'
        };
      }
    } catch (e) {
      return {'status': 'error', 'message': 'Connection failed: $e'};
    }
  }
}
