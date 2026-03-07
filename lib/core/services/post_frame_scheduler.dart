import 'package:flutter/widgets.dart';

import 'i_post_frame_scheduler.dart';

class PostFrameScheduler implements IPostFrameScheduler {
  const PostFrameScheduler();

  @override
  void schedulePostFrame(VoidCallback callback) {
    WidgetsBinding.instance.addPostFrameCallback((_) => callback());
  }
}
