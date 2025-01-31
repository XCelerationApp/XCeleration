import 'dart:convert';

class Package {
  final int number;
  final String type;
  final String? data;
  late int checksum;
  Package({
    required this.number,
    required this.type,
    this.data,
  }) {
    if (type == 'DATA') {
      checksum = _calculateChecksum();
    }
  }

  bool checksumsMatch() => checksum == _calculateChecksum();

  int _calculateChecksum() => 1;

  @override
  String toString() {
    return jsonEncode(toJson());
  }

  Map<String, dynamic> toJson() {
    return {'number': number, 'type': type, 'data': data, 'checksum': checksum};
  }

  factory Package.fromJson(Map<String, dynamic> json) {
    return Package(
      number: json['number'],
      type: json['type'],
      data: json['data'],
    )..checksum = json['checksum'];
  }

  factory Package.fromString(String encodedJson) {
    Map<String, dynamic> json = jsonDecode(encodedJson);
    return Package.fromJson(json);
  }

}