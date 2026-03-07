import 'package:share_plus/share_plus.dart';

abstract interface class IShareService {
  Future<void> share(ShareParams params);
}
