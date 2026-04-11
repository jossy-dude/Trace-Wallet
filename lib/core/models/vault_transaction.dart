import 'package:isar/isar.dart';
import 'package:json_annotation/json_annotation.dart';

part 'vault_transaction.g.dart';

@collection
@JsonSerializable()
class VaultTransaction {
  Id id = Isar.autoIncrement;

  late String rawText;
  double? amount;
  double? balance; // New
  double? fee; // New
  
  @Index()
  late DateTime date;
  
  String? senderAlias;
  
  @Index()
  String? category;
  
  String? aiSummary;
  bool isApproved = false;
  bool sentToDad = false;

  VaultTransaction({
    this.id = Isar.autoIncrement,
    required this.rawText,
    this.amount,
    this.balance,
    this.fee,
    required this.date,
    this.senderAlias,
    this.category,
    this.aiSummary,
    this.isApproved = false,
    this.sentToDad = false,
  });

  factory VaultTransaction.fromJson(Map<String, dynamic> json) => _$VaultTransactionFromJson(json);
  Map<String, dynamic> toJson() => _$VaultTransactionToJson(this);
}
