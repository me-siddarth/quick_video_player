import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'video_analytics_tracker.dart';

/// Controls available for the video player
enum VideoPlayerControls {
  playPause,
  progressBar,
  speedControl,
  fullscreen,
  rotate,
}

/// Action to be performed on video tap
enum ClickAction {
  none,
  playPause,
  showControls,
}

enum Format {
  /// Dynamic Adaptive Streaming over HTTP, also known as MPEG-DASH.
  dash,

  /// HTTP Live Streaming.
  hls,

  /// Smooth Streaming.
  ss,

  /// Any format other than the other ones defined in this enum.
  other,
}

class QuickVideoPlayer extends StatefulWidget {
  const QuickVideoPlayer({
    super.key,
    required this.videoUrl,
    this.autoPlay = false,
    this.startAt,
    this.looping = false,
    this.videoFormat,
    this.aspectRatio,
    this.backgroundColor = Colors.black,
    this.thumbnailUrl,
    this.overlay,
    this.loadingIndicator,
    this.errorIndicator,
    this.controlsToShow = const [VideoPlayerControls.playPause],
    this.showControlsOnInitialize = false,
    this.showControlsAlways = false,
    this.controlsVisibilityDuration = 3,
    this.clickAction = ClickAction.showControls,
    this.controlsPositionOffset = Offset.zero,
    this.onInitialized,
    this.onError,
    this.onBuffering,
    this.onPlayPauseChanged,
    this.onPositionChanged,
    this.onDurationChanged,
    this.onFullscreenChanged,
    this.onCompleted,
    this.onPlay,
    this.videoId,
    this.videoTitle,
    this.videoCategory,
    this.videoProvider = 'quick_player',
    this.showProgress = false,
    this.allowSeek = false,
  });

  final VoidCallback? onPlay;

  final String videoUrl;

  final String? videoId;

  final String? videoTitle;

  final String? videoCategory;

  final String videoProvider;

  final String? thumbnailUrl;

  final Format? videoFormat;

  final bool autoPlay;

  final Duration? startAt;

  final bool looping;

  final List<VideoPlayerControls> controlsToShow;

  final ClickAction clickAction;

  final int controlsVisibilityDuration;

  final Offset controlsPositionOffset;

  final double? aspectRatio;

  final bool showControlsOnInitialize;

  final bool showControlsAlways;

  final Color? backgroundColor;

  final Widget? overlay;

  final Widget? loadingIndicator;

  final Widget? errorIndicator;

  final Function()? onInitialized;

  final Function()? onCompleted;

  final Function(bool)? onPlayPauseChanged;

  final Function(bool)? onBuffering;

  final Function(bool)? onFullscreenChanged;

  final Function(Duration)? onPositionChanged;

  final Function(Duration)? onDurationChanged;

  final Function(Error)? onError;

  final bool showProgress;

  final bool allowSeek;

  @override
  State<QuickVideoPlayer> createState() => _QuickVideoPlayerState();
}

class _QuickVideoPlayerState extends State<QuickVideoPlayer>
    with TickerProviderStateMixin {
  VideoPlayerController? _controller;
  VoidCallback? _videoListener;
  AnimationController? _playPauseAnimationController;
  Animation<double>? _playPauseAnimation;
  bool _showPlayPauseIcon = false;
  bool _isVisible = false;
  String _uniqueKey = '';
  bool _isInitialized = false;
  bool _isPlaying = false;
  bool _isBuffering = false;
  bool _hasError = false;
  String? _errorMessage;
  bool _showControls = false;
  bool _hasPlayedOnce = false;
  bool _isLandscape = false;

  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isSeeking = false;

  bool _hasVideoStarted = false;
  int _lastVideoPosition = 0;
  final Set<int> _loggedMilestones = {};
  bool _has30SecondMilestone = false;
  bool _hasCompleted = false;

  @override
  void initState() {
    super.initState();
    _uniqueKey =
        'video_${DateTime.now().millisecondsSinceEpoch}_${widget.videoUrl.hashCode}';
    _videoListener = _getVideoListener;
    _initializeVideo();
    _initializePlayPauseAnimation();
  }

  void _initializeVideo() async {
    final trimmedUrl = widget.videoUrl.trim();
    if (trimmedUrl.isEmpty || !trimmedUrl.startsWith('http')) {
      setState(() {
        _hasError = true;
      });
      widget.onError?.call(
          StateError('Video URL is empty or invalid: ${widget.videoUrl}'));
      return;
    }

    // On Android, ExoPlayer crashes (fatal native exception) if the URL path
    // contains ':' or '%3A' beyond the scheme — it misparses it as a second
    // scheme separator, treating the URI as non-hierarchical.
    if (defaultTargetPlatform == TargetPlatform.android) {
      final pathStart = trimmedUrl.indexOf('://');
      final rawPath =
          pathStart != -1 ? trimmedUrl.substring(pathStart + 3) : trimmedUrl;
      if (rawPath.contains('%3A') ||
          rawPath.contains('%3a') ||
          Uri.parse(trimmedUrl).path.contains(':')) {
        setState(() {
          _hasError = true;
          _errorMessage = 'URL unsupported';
        });
        widget.onError?.call(StateError('URL unsupported'));
        return;
      }
    }

    if (_controller != null) {
      if (_isVisible && widget.autoPlay) {
        _controller?.play();
      }
      return;
    }

    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(trimmedUrl),
        formatHint: VideoFormat.values.cast<VideoFormat?>().firstWhere(
            (e) => e?.name == widget.videoFormat?.name,
            orElse: () => null),
      )
        ..setLooping(widget.looping)
        ..addListener(_videoListener!);
      await _controller?.initialize();
      setState(() {
        _isInitialized = true;
        _hasError = false;
      });
      widget.onInitialized?.call();
      if (widget.startAt != null) {
        await _controller?.seekTo(widget.startAt!);
      }
      if (_isVisible && widget.autoPlay) {
        _controller?.play();
      }
      if (widget.showControlsOnInitialize || widget.showControlsAlways) {
        _toggleControlsVisibility();
      }
    } catch (e) {
      setState(() {
        _hasError = true;
      });
      widget.onError
          ?.call(StateError('Failed to initialize video controller: $e'));
    }
  }

  void _initializePlayPauseAnimation() {
    _playPauseAnimationController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _playPauseAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _playPauseAnimationController!,
      curve: Curves.easeInOut,
    ));
  }

  VoidCallback get _getVideoListener {
    return () {
      if (!mounted || _controller == null) return;

      final isPlaying = _controller?.value.isPlaying ?? false;
      final isBuffering = _controller?.value.isBuffering ?? false;
      final position = _controller?.value.position ?? Duration.zero;
      final duration = _controller?.value.duration ?? Duration.zero;

      if (isPlaying && !_hasPlayedOnce) {
        _hasPlayedOnce = true;
        widget.onPlay?.call();
      }

      if (isPlaying != _isPlaying) {
        setState(() {
          _isPlaying = isPlaying;
        });
        isPlaying ? WakelockPlus.enable() : WakelockPlus.disable();
        widget.onPlayPauseChanged?.call(isPlaying);
      }

      if (isBuffering != _isBuffering) {
        setState(() {
          _isBuffering = isBuffering;
        });
        widget.onBuffering?.call(isBuffering);
      }

      if (!_isSeeking) {
        if (position != _currentPosition || duration != _totalDuration) {
          setState(() {
            _currentPosition = position;
            _totalDuration = duration;
          });
        }
      }

      widget.onPositionChanged?.call(position);
      widget.onDurationChanged?.call(duration);

      if (duration > Duration.zero &&
          position >= duration &&
          !_controller!.value.isLooping &&
          !_hasCompleted) {
        _hasCompleted = true;
        widget.onCompleted?.call();
      }

      _trackVideoAnalytics(isPlaying, position, duration);
    };
  }

  void _trackVideoAnalytics(
    bool isPlaying,
    Duration position,
    Duration duration,
  ) {
    if (_controller == null || duration.inSeconds == 0) return;

    final positionSeconds = position.inSeconds;
    final durationSeconds = duration.inSeconds;
    final videoId = widget.videoId ?? widget.videoUrl;
    final videoTitle = widget.videoTitle ?? 'Untitled Video';
    final videoCategory = widget.videoCategory ?? 'custom';
    final tracker = videoAnalyticsTracker;

    if (isPlaying && !_hasVideoStarted) {
      _hasVideoStarted = true;
      tracker.onStart(
        videoId: videoId,
        videoTitle: videoTitle,
        videoDuration: durationSeconds,
        videoCategory: videoCategory,
        videoProvider: widget.videoProvider,
      );
    }

    if (!isPlaying && _hasVideoStarted && _lastVideoPosition > 0) {
      tracker.onPause(
        videoId: videoId,
        videoTitle: videoTitle,
        videoPosition: positionSeconds,
        videoDuration: durationSeconds,
        videoCategory: videoCategory,
        videoProvider: widget.videoProvider,
      );
    }

    if (isPlaying && positionSeconds != _lastVideoPosition) {
      if (_lastVideoPosition > 0 &&
          (positionSeconds - _lastVideoPosition).abs() > 2) {
        if (positionSeconds < _lastVideoPosition) {
          tracker.onRewind(
            videoId: videoId,
            videoTitle: videoTitle,
            videoPosition: positionSeconds,
            videoDuration: durationSeconds,
            videoCategory: videoCategory,
            videoProvider: widget.videoProvider,
          );
        } else {
          tracker.onFastForward(
            videoId: videoId,
            videoTitle: videoTitle,
            videoPosition: positionSeconds,
            videoDuration: durationSeconds,
            videoCategory: videoCategory,
            videoProvider: widget.videoProvider,
          );
        }
      }

      _trackVideoProgress(
          videoId, videoTitle, positionSeconds, durationSeconds, videoCategory);
    }

    if (duration > Duration.zero &&
        position >= duration &&
        !_controller!.value.isLooping) {
      tracker.onComplete(
        videoId: videoId,
        videoTitle: videoTitle,
        videoDuration: durationSeconds,
        videoCategory: videoCategory,
        videoProvider: widget.videoProvider,
      );
    }

    _lastVideoPosition = positionSeconds;
  }

  void _trackVideoProgress(
    String videoId,
    String videoTitle,
    int position,
    int duration,
    String videoCategory,
  ) {
    if (duration == 0) return;
    final tracker = videoAnalyticsTracker;

    if (position >= 30 && !_has30SecondMilestone) {
      _has30SecondMilestone = true;
      tracker.onProgress(
        videoId: videoId,
        videoTitle: videoTitle,
        videoPosition: position,
        videoDuration: duration,
        milestone: '30s',
        videoCategory: videoCategory,
        videoProvider: widget.videoProvider,
      );
    }

    final progressPercent = (position / duration * 100).round();
    final milestone = (progressPercent ~/ 10) * 10;

    if (milestone >= 10 &&
        milestone <= 100 &&
        !_loggedMilestones.contains(milestone)) {
      _loggedMilestones.add(milestone);
      tracker.onProgress(
        videoId: videoId,
        videoTitle: videoTitle,
        videoPosition: position,
        videoDuration: duration,
        milestone: '$milestone%',
        videoCategory: videoCategory,
        videoProvider: widget.videoProvider,
      );
    }
  }

  @override
  void dispose() {
    if (_controller != null && _hasVideoStarted) {
      try {
        final position = _controller!.value.position.inSeconds;
        final duration = _controller!.value.duration.inSeconds;
        final videoId = widget.videoId ?? widget.videoUrl;
        final videoTitle = widget.videoTitle ?? 'Untitled Video';
        final videoCategory = widget.videoCategory ?? 'custom';

        videoAnalyticsTracker.onStop(
          videoId: videoId,
          videoTitle: videoTitle,
          videoPosition: position,
          videoDuration: duration,
          videoCategory: videoCategory,
          videoProvider: widget.videoProvider,
        );
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error tracking video stop: $e');
        }
      }
    }

    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    WakelockPlus.disable();
    if (_videoListener != null) {
      _controller?.removeListener(_videoListener!);
    }
    _videoListener = null;
    _controller?.dispose();
    _controller = null;
    _playPauseAnimationController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key(_uniqueKey),
      onVisibilityChanged: _onVisibilityChanged,
      child: Container(
        color: widget.backgroundColor,
        child: _hasError
            ? _getErrorWidget
            : !_isInitialized
                ? _getLoadingWidget
                : GestureDetector(
                    onTap: _onVideoTap,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            Center(
                              child: AspectRatio(
                                aspectRatio: widget.aspectRatio ??
                                    _controller!.value.aspectRatio,
                                child: VideoPlayer(_controller!),
                              ),
                            ),
                            if (widget.overlay != null)
                              Positioned.fill(
                                child: IgnorePointer(
                                  ignoring: false,
                                  child: widget.overlay!,
                                ),
                              ),
                            _buildPlayPauseAnimation(),
                            if (_showControls) ..._controlsOverlay(),
                            if (widget.showProgress) _buildProgressBar(),
                          ],
                        );
                      },
                    ),
                  ),
      ),
    );
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    final visibleFraction = info.visibleFraction;
    final wasVisible = _isVisible;
    _isVisible = visibleFraction > (wasVisible ? 0.30 : 0.50);
    if (_isVisible != wasVisible) {
      if (_isVisible) {
        if (widget.autoPlay && _isInitialized && !_isPlaying) {
          _controller?.play();
        }
      } else {
        _controller?.pause();
      }
    }
  }

  void _toggleControlsVisibility() {
    if (widget.showControlsAlways) {
      if (!_showControls) {
        setState(() {
          _showControls = true;
        });
      }
      return;
    }
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      Future.delayed(Duration(seconds: widget.controlsVisibilityDuration), () {
        if (mounted) {
          setState(() {
            _showControls = false;
          });
        }
      });
    }
  }

  void _onVideoTap() {
    switch (widget.clickAction) {
      case ClickAction.playPause:
        if (_isPlaying) {
          _controller?.pause();
        } else {
          _controller?.play();
        }
        _triggerPlayPauseAnimation();
        break;
      case ClickAction.showControls:
        _toggleControlsVisibility();
        break;
      case ClickAction.none:
        break;
    }
  }

  void _triggerPlayPauseAnimation() {
    if (!(_showControls &&
        widget.controlsToShow.contains(VideoPlayerControls.playPause))) {
      setState(() {
        _showPlayPauseIcon = true;
      });

      _playPauseAnimationController?.forward(from: 0.0).then((_) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            _playPauseAnimationController?.reverse().then((_) {
              if (mounted) {
                setState(() {
                  _showPlayPauseIcon = false;
                });
              }
            });
          }
        });
      });
    }
  }

  List<Widget> _controlsOverlay() {
    return widget.controlsToShow.map((ctrl) {
      switch (ctrl) {
        case VideoPlayerControls.playPause:
          return _playPauseControl();
        case VideoPlayerControls.rotate:
          return SizedBox.shrink();
        default:
          return SizedBox.shrink();
      }
    }).toList();
  }

  Widget get _getErrorWidget {
    return (widget.errorIndicator ??
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.error,
                color: Colors.white.withValues(alpha: 0.5), size: 48),
            SizedBox(height: 8),
            Text(_errorMessage ?? 'Error loading video',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5)))
          ],
        ));
  }

  Widget get _getLoadingWidget {
    return (widget.loadingIndicator ??
        const Center(child: CircularProgressIndicator()));
  }

  Widget _buildPlayPauseAnimation() {
    if (!_showPlayPauseIcon) return const SizedBox.shrink();

    return Center(
      child: AnimatedBuilder(
        animation: _playPauseAnimation!,
        builder: (context, child) {
          return Opacity(
            opacity: _playPauseAnimation!.value,
            child: Transform.scale(
              scale: 0.5 + (_playPauseAnimation!.value * 0.2),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _controller!.value.isPlaying ? Icons.play_arrow : Icons.pause,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 48,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _playPauseControl() {
    return Center(
      child: IconButton(
        icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow,
            color: Colors.white, size: 48),
        onPressed: () {
          if (_isPlaying) {
            _controller?.pause();
          } else {
            _controller?.play();
          }
        },
      ),
    );
  }

  void _onRotateTap() {
    setState(() {
      _isLandscape = !_isLandscape;
    });

    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }

    widget.onFullscreenChanged?.call(_isLandscape);
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  Widget _buildProgressBar() {
    final progress = _totalDuration.inMilliseconds > 0
        ? _currentPosition.inMilliseconds / _totalDuration.inMilliseconds
        : 0.0;

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [
              Colors.black.withValues(alpha: 0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(_currentPosition),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatDuration(_totalDuration),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (widget.controlsToShow
                          .contains(VideoPlayerControls.rotate))
                        GestureDetector(
                          onTap: _onRotateTap,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Icon(
                              Icons.screen_rotation,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              widget.allowSeek
                  ? _buildSeekableProgressBar(progress)
                  : _buildNonSeekableProgressBar(progress),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNonSeekableProgressBar(double progress) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: LinearProgressIndicator(
        value: progress.clamp(0.0, 1.0),
        backgroundColor: Colors.white.withValues(alpha: 0.3),
        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
        minHeight: 4,
      ),
    );
  }

  Widget _buildSeekableProgressBar(double progress) {
    return GestureDetector(
      onHorizontalDragStart: (_) {
        setState(() {
          _isSeeking = true;
        });
      },
      onHorizontalDragUpdate: (details) {
        if (_controller == null || _totalDuration.inMilliseconds == 0) {
          return;
        }

        final box = context.findRenderObject() as RenderBox?;
        if (box == null) {
          return;
        }

        final localPosition = details.localPosition.dx;
        final width = box.size.width - 32;
        final seekProgress = (localPosition / width).clamp(0.0, 1.0);
        final seekPosition = Duration(
          milliseconds: (seekProgress * _totalDuration.inMilliseconds).round(),
        );

        setState(() {
          _currentPosition = seekPosition;
        });
      },
      onHorizontalDragEnd: (_) {
        if (mounted &&
            _controller != null &&
            _controller!.value.isInitialized) {
          _controller!.seekTo(_currentPosition);
        }
        setState(() {
          _isSeeking = false;
        });
      },
      onTapUp: (details) {
        if (!mounted ||
            _controller == null ||
            !_controller!.value.isInitialized ||
            _totalDuration.inMilliseconds == 0) {
          return;
        }

        final box = context.findRenderObject() as RenderBox?;
        if (box == null) {
          return;
        }

        final localPosition = details.localPosition.dx;
        final width = box.size.width - 32;
        final seekProgress = (localPosition / width).clamp(0.0, 1.0);
        final seekPosition = Duration(
          milliseconds: (seekProgress * _totalDuration.inMilliseconds).round(),
        );

        _controller!.seekTo(seekPosition);
      },
      child: Container(
        height: 25,
        alignment: Alignment.center,
        color: Colors.transparent,
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            FractionallySizedBox(
              widthFactor: progress.clamp(0.0, 1.0),
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Positioned(
              left: (progress.clamp(0.0, 1.0) *
                      (MediaQuery.of(context).size.width - 32)) -
                  8,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
