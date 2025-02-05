import 'dart:convert';
import 'package:crypto/crypto.dart';

class Package {
  final int number;
  final String type;
  late String? data;
  late String? checksum;
  Package({
    required this.number,
    required this.type,
    this.data
  }) {
    if (type == 'DATA' && data != null) {
      data = data;
      checksum = _calculateChecksum();
    }
  }

  bool checksumsMatch() => checksum == _calculateChecksum();

  String? _calculateChecksum() {
    if (type != 'DATA' || data == null) {
      return null;
    }
    return sha256.convert(utf8.encode(data!)).toString();
  }

  @override
  String toString() {
    return jsonEncode(toJson());
  }

  Map<String, dynamic> toJson() {
    return {
      'number': number,
      'type': type,
      if (type == 'DATA') 'data': data,
      if (type == 'DATA') 'checksum': checksum,
    };
  }

  factory Package.fromJson(Map<String, dynamic> json) {
    Package package = Package(
      number: json['number'],
      type: json['type'],
    );
    if (package.type != 'DATA') return package;
    package.data = json['data'];
    package.checksum = json['checksum'];
    return package;
  }

  factory Package.fromString(String encodedJson) {
    Map<String, dynamic> json = jsonDecode(encodedJson);
    return Package.fromJson(json);
  }

}