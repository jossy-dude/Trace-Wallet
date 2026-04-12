import 'package:isar/isar.dart';
import 'database_service.dart';
import '../models/vault_transaction.dart';
import '../models/vault_person.dart';
import 'regex_parser_service.dart';

class AliasService {
  static final AliasService _instance = AliasService._internal();
  factory AliasService() => _instance;
  AliasService._internal();

  final _db = DatabaseService();
  final _parser = RegexParserService();

  /// Matches the transaction to a person based on aliases found in the text.
  Future<VaultTransaction> mapTransactionToPerson(VaultTransaction tx) async {
    final rawName = _parser.extractProbableEntity(tx.rawText);
    
    if (rawName == null) {
      tx.category = 'Requires Review';
      return tx;
    }

    // Search for a person who has this entity in their alias list
    final person = await _db.isar.vaultPersons
        .filter()
        .aliasesElementEqualTo(rawName, caseSensitive: false)
        .findFirst();

    if (person != null) {
      tx.senderAlias = person.name;
    } else {
      // No match found - keep the raw name as alias
      tx.senderAlias = rawName;
      // Only flag for review if it wasn't already successfully categorized by the Bank Parser
      bool isBankTx = tx.category == 'CBE' || tx.category == 'Telebirr' || tx.category == 'BOA';
      if (!isBankTx) {
        tx.category = 'Requires Review';
      }
    }

    return tx;
  }
}
