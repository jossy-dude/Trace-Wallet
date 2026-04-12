import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/vault_transaction.dart';
import '../models/vault_person.dart';
import '../models/paired_device.dart';

class DatabaseService {
  // Singleton instance
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  late Isar _isar;

  // Getter for the Isar instance
  Isar get isar => _isar;

  Future<void> init() async {
    // Get local documents directory for storage
    final dir = await getApplicationDocumentsDirectory();

    // Open Isar with our defined schemas
    _isar = await Isar.open(
      [VaultTransactionSchema, VaultPersonSchema, PairedDeviceSchema],
      directory: dir.path,
    );
  }

  // Helper method to close database if needed
  Future<void> close() async {
    await _isar.close();
  }
}
