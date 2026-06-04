/// Pluggable analytics surface for [VideoPlayerView].
///
/// The host app registers an implementation via [setVideoAnalyticsTracker] so
/// this package stays free of any concrete analytics SDK dependency.
abstract class VideoAnalyticsTracker {
  void onStart({
    required String videoId,
    required String videoTitle,
    required int videoDuration,
    String? videoCategory,
    String? videoProvider,
  });

  void onPause({
    required String videoId,
    required String videoTitle,
    required int videoPosition,
    required int videoDuration,
    String? videoCategory,
    String? videoProvider,
  });

  void onRewind({
    required String videoId,
    required String videoTitle,
    required int videoPosition,
    required int videoDuration,
    String? videoCategory,
    String? videoProvider,
  });

  void onFastForward({
    required String videoId,
    required String videoTitle,
    required int videoPosition,
    required int videoDuration,
    String? videoCategory,
    String? videoProvider,
  });

  void onProgress({
    required String videoId,
    required String videoTitle,
    required int videoPosition,
    required int videoDuration,
    required String milestone,
    String? videoCategory,
    String? videoProvider,
  });

  void onComplete({
    required String videoId,
    required String videoTitle,
    required int videoDuration,
    String? videoCategory,
    String? videoProvider,
  });

  void onStop({
    required String videoId,
    required String videoTitle,
    required int videoPosition,
    required int videoDuration,
    String? videoCategory,
    String? videoProvider,
  });
}

class _NoopVideoAnalyticsTracker implements VideoAnalyticsTracker {
  const _NoopVideoAnalyticsTracker();
  @override
  void onStart({
    required String videoId,
    required String videoTitle,
    required int videoDuration,
    String? videoCategory,
    String? videoProvider,
  }) {}
  @override
  void onPause({
    required String videoId,
    required String videoTitle,
    required int videoPosition,
    required int videoDuration,
    String? videoCategory,
    String? videoProvider,
  }) {}
  @override
  void onRewind({
    required String videoId,
    required String videoTitle,
    required int videoPosition,
    required int videoDuration,
    String? videoCategory,
    String? videoProvider,
  }) {}
  @override
  void onFastForward({
    required String videoId,
    required String videoTitle,
    required int videoPosition,
    required int videoDuration,
    String? videoCategory,
    String? videoProvider,
  }) {}
  @override
  void onProgress({
    required String videoId,
    required String videoTitle,
    required int videoPosition,
    required int videoDuration,
    required String milestone,
    String? videoCategory,
    String? videoProvider,
  }) {}
  @override
  void onComplete({
    required String videoId,
    required String videoTitle,
    required int videoDuration,
    String? videoCategory,
    String? videoProvider,
  }) {}
  @override
  void onStop({
    required String videoId,
    required String videoTitle,
    required int videoPosition,
    required int videoDuration,
    String? videoCategory,
    String? videoProvider,
  }) {}
}

VideoAnalyticsTracker _tracker = const _NoopVideoAnalyticsTracker();

VideoAnalyticsTracker get videoAnalyticsTracker => _tracker;

void setVideoAnalyticsTracker(VideoAnalyticsTracker tracker) {
  _tracker = tracker;
}
