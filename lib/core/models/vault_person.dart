import 'package:isar/isar.dart';
import 'package:json_annotation/json_annotation.dart';

part 'vault_person.g.dart';

@collection
@JsonSerializable()
class VaultPerson {
  Id id = Isar.autoIncrement;

  late String name;
  List<String> aliases = [];
  double monthlyFee = 0.0;

  VaultPerson({
    this.id = Isar.autoIncrement,
    required this.name,
    this.aliases = const [],
    this.monthlyFee = 0.0,
  });

  factory VaultPerson.fromJson(Map<String, dynamic> json) => _$VaultPersonFromJson(json);
  Map<String, dynamic> toJson() => _$VaultPersonToJson(this);
}
