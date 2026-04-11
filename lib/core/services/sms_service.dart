import 'package:telephony/telephony.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/vault_transaction.dart';
import '../models/vault_person.dart';

// Top-level function for background execution
@pragma('vm:entry-point')
void backgroundMessageHandler(SmsMessage message) async {
  final String? body = message.body;
  if (body == null) return;

  // 1. Initial categorization
  final bool isFinancial = body.toLowerCase().contains('etb') || 
                           body.toLowerCase().contains('bank') || 
                           body.toLowerCase().contains('telebirr');

  if (isFinancial) {
    // 2. Open Isar (Stable Initialization)
    final dir = await getApplicationDocumentsDirectory();
    
    // Check if Isar is already open in this isolate
    Isar? isar = Isar.getInstance();
    if (isar == null) {
      isar = await Isar.open(
        [VaultTransactionSchema, VaultPersonSchema],
        directory: dir.path,
      );
    }

    final transaction = VaultTransaction(
      rawText: body,
      date: DateTime.now(),
      senderAlias: message.address,
      category: 'Captured', // Generic tag, refined on PC
      isApproved: false,
    );

    await isar!.writeTxn(() async {
      await isar!.vaultTransactions.put(transaction);
    });
    
    // 3. Local notification or forwarding logic
    const String overseerNumber = "+1234567890";
    await Telephony.instance.sendSms(
      to: overseerNumber,
      message: "Vault captured a transaction: ${message.address}",
    );
  }
}

class SmsService {
  static final SmsService _instance = SmsService._internal();
  factory SmsService() => _instance;
  SmsService._internal();

  final Telephony _telephony = Telephony.instance;

  Future<void> init() async {
    // Request permissions and start listening
    bool? permissionsGranted = await _telephony.requestPhoneAndSmsPermissions;

    if (permissionsGranted != null && permissionsGranted) {
      _telephony.listenIncomingSms(
        onNewMessage: (SmsMessage message) {
          // Handle foreground message if needed
          print("New message received in foreground: ${message.body}");
          // We can call the same handler logic here or let the user know
        },
        onBackgroundMessage: backgroundMessageHandler,
      );
    }
  }
}
