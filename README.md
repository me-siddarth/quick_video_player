# quick_video_player

A reusable network video player and vertical short-form ("reels"-style) video
feed for Flutter. Built on top of [`video_player`](https://pub.dev/packages/video_player)
with configurable controls, fullscreen, an optional info overlay, and a
pluggable analytics surface that keeps the package free of any concrete
analytics SDK.

## Features

- Network video playback (mp4 / HLS / DASH / Smooth Streaming).
- Configurable controls: play/pause, progress bar, speed, fullscreen, rotate.
- Vertical paginated feed via [`infinite_scroll_pagination`](https://pub.dev/packages/infinite_scroll_pagination).
- Auto play/pause on visibility, wakelock while playing.
- Optional overlay (title, description, like, share).
- Pluggable analytics — bring your own tracker.

## Installation

Add it from git in your app's `pubspec.yaml`:

```yaml
dependencies:
  quick_video_player:
    git:
      url: https://github.com/<your-org>/quick_video_player.git
      ref: main
```

## Usage

### Single player

```dart
import 'package:quick_video_player/quick_video_player.dart';

QuickVideoPlayer(
  videoUrl: 'https://example.com/video.mp4',
  autoPlay: true,
  looping: true,
  controlsToShow: const [
    VideoPlayerControls.playPause,
    VideoPlayerControls.progressBar,
    VideoPlayerControls.fullscreen,
  ],
)
```

### Vertical feed

```dart
QuickPlayerFeed<MyItem>(
  controller: pagingController,
  videoUrlBuilder: (item) => item.url,
  overlayBuilder: (context, item, index) => QuickPlayerOverlay(
    title: item.title,
    tagline: item.tagline,
    shareUrl: item.shareUrl,
    shareSubject: 'My App', // optional; defaults to empty
  ),
)
```

### Analytics (optional)

Register an implementation once at startup; the package calls it on play,
pause, progress milestones, complete, etc.

```dart
class MyTracker extends VideoAnalyticsTracker {
  // override onStart / onProgress / onComplete / ...
}

void main() {
  setVideoAnalyticsTracker(MyTracker());
  runApp(const MyApp());
}
```

If no tracker is registered, a no-op tracker is used.

## License

See [LICENSE](LICENSE).
