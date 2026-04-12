import 'package:isar/isar.dart';

part 'paired_device.g.dart';

@collection
class PairedDevice {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  String? deviceId;
  
  String? name;
  DateTime? addedAt;
  DateTime? lastSeen;
  bool isTrusted = false;
  
  String? ipAddress;
  String? deviceType; // 'mobile' | 'desktop'
}
