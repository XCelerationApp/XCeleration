import 'package:barcode_scan2/barcode_scan2.dart';

abstract class BarcodeScannerInterface {
  Future<ScanResult> scan();
}

class DefaultBarcodeScanner implements BarcodeScannerInterface {
  const DefaultBarcodeScanner();

  @override
  Future<ScanResult> scan() => BarcodeScanner.scan();
}
