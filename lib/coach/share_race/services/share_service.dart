import 'package:share_plus/share_plus.dart';
import 'i_share_service.dart';

class ShareService implements IShareService {
  @override
  Future<void> share(ShareParams params) async {
    await SharePlus.instance.share(params);
  }
}
