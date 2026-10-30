import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

import 'quick_video_player.dart';

/// Vertical-feed quick player feed backed by an [infinite_scroll_pagination]
/// [PagingController].
class QuickPlayerFeed<T> extends StatefulWidget {
  const QuickPlayerFeed({
    super.key,
    required this.controller,
    required this.videoUrlBuilder,
    this.scrollDirection = Axis.vertical,
    this.refreshable = true,
    this.allowImplicitScrolling = true,
    this.addAutomaticKeepAlives = true,
    this.autoPlayNext = false,
    this.edgeOffset = 0,
    this.overlayBuilder,
    this.expandOverlay = false,
    this.noMoreItemsIndicator,
    this.firstPageLoadingIndicator,
    this.itemLoadingIndicator,
    this.bottomPadding,
    this.onRefreshData,
    this.onItemChanged,
    this.onVideoStarted,
    this.onDurationChanged,
    this.onItemDurationChanged,
    this.onPositionChanged,
    this.onPlayPauseChanged,
    this.onVideoCompleted,
    this.onListEnded,
    this.onListEndCancelled,
    this.videoIdBuilder,
    this.videoTitleBuilder,
    this.videoCategory,
    this.showProgress = false,
    this.allowSeek = false,
    this.showRotate = false,
    this.onFullscreenChanged,
  });

  final void Function(T item, int index)? onVideoStarted;

  final void Function(T item, Duration position)? onPositionChanged;

  final void Function(T item, bool isPlaying)? onPlayPauseChanged;

  final void Function(T item)? onVideoCompleted;

  /// Fires when the reader swipes past the last reel and nothing follows.
  final VoidCallback? onListEnded;

  /// Fires when they swipe back onto a reel before the list restarts.
  final VoidCallback? onListEndCancelled;

  final void Function(T item, int index)? onItemChanged;

  final Future<void> Function()? onRefreshData;

  final void Function(Duration duration)? onDurationChanged;

  final void Function(T item, Duration duration)? onItemDurationChanged;

  /// Paging controller to manage pagination
  final PagingController<int, T> controller;

  /// Whether to auto scroll the quick player feed
  final bool autoScroll = false;

  /// Scroll direction of the quick player feed
  final Axis scrollDirection;

  /// Whether the quick player feed is refreshable
  final bool refreshable;

  /// Whether to allow implicit scrolling
  final bool allowImplicitScrolling;

  /// Whether to add automatic keep alives
  final bool addAutomaticKeepAlives;

  /// Edge offset for the refresh indicator
  final double edgeOffset;

  final bool autoPlayNext;

  final Widget? noMoreItemsIndicator;

  /// Widget rendered while the FIRST page is loading.
  final Widget? firstPageLoadingIndicator;

  /// Widget rendered as the loading placeholder INSIDE each video card while
  /// the network video initializes. Pass a shimmer if you want one.
  final Widget? itemLoadingIndicator;

  final String Function(T item) videoUrlBuilder;

  final Widget Function(BuildContext, T, int)? overlayBuilder;

  /// Lets the overlay cover the whole frame, including top controls.
  final bool expandOverlay;

  final double? bottomPadding;

  /// Builder function to extract video ID from item for analytics
  final String Function(T item)? videoIdBuilder;

  /// Builder function to extract video title from item for analytics
  final String Function(T item)? videoTitleBuilder;

  /// Video category for analytics (e.g., 'stories', 'industry_unplugged')
  final String? videoCategory;

  /// Whether to show progress bar with time at the bottom
  final bool showProgress;

  /// Whether to allow user to seek by dragging the progress bar
  final bool allowSeek;

  /// Whether to show the rotate button (default: false)
  final bool showRotate;

  /// Callback when fullscreen/rotation state changes
  final Function(bool)? onFullscreenChanged;

  @override
  State<QuickPlayerFeed<T>> createState() => _QuickPlayerFeedState<T>();
}

class _QuickPlayerFeedState<T> extends State<QuickPlayerFeed<T>> {
  final PageController _pageController = PageController(keepPage: true);
  final ValueNotifier<bool> _sharedMuted = ValueNotifier(false);

  @override
  void dispose() {
    _sharedMuted.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final child = _buildFeedPageView();
    if (widget.refreshable) {
      return RefreshIndicator(
        edgeOffset: widget.edgeOffset,
        onRefresh: () async {
          if (widget.onRefreshData != null) {
            await widget.onRefreshData!();
          } else {
            widget.controller.refresh();
          }
        },
        child: child,
      );
    }
    return child;
  }

  Widget _buildFeedPageView() {
    return PagingListener<int, T>(
      controller: widget.controller,
      builder: (context, state, fetchNextPage) {
        final List<T> loadedItems = [];

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (widget.onItemChanged != null &&
              loadedItems.isNotEmpty &&
              _pageController.hasClients &&
              _pageController.page == 0) {
            widget.onItemChanged!(loadedItems[0], 0);
          }
        });

        return PagedPageView<int, T>(
          pageController: _pageController,
          state: state,
          fetchNextPage: fetchNextPage,
          scrollDirection: widget.scrollDirection,
          allowImplicitScrolling: widget.allowImplicitScrolling,
          addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
          onPageChanged: (index) {
            final count = state.items?.length ?? 0;
            if (count > 0 && index >= count) {
              widget.onListEnded?.call();
            } else {
              widget.onListEndCancelled?.call();
            }
            if (widget.onItemChanged != null &&
                index >= 0 &&
                index < loadedItems.length) {
              widget.onItemChanged!(loadedItems[index], index);
            }
          },
          builderDelegate: PagedChildBuilderDelegate<T>(
            firstPageProgressIndicatorBuilder:
                widget.firstPageLoadingIndicator != null
                    ? (ctx) => widget.firstPageLoadingIndicator!
                    : null,
            noMoreItemsIndicatorBuilder: widget.noMoreItemsIndicator != null
                ? (ctx) => widget.noMoreItemsIndicator!
                : null,
            itemBuilder: (context, item, index) {
              if (loadedItems.length <= index) {
                loadedItems.add(item);
              } else {
                loadedItems[index] = item;
              }
              return _pageViewItemBuilder(context, item, index);
            },
          ),
        );
      },
    );
  }

  Widget _pageViewItemBuilder(BuildContext context, T item, int index) {
    return QuickVideoPlayer(
      autoPlay: true,
      controlsPositionOffset: Offset.zero,
      controlsToShow: [
        if (widget.showRotate) VideoPlayerControls.rotate,
      ],
      clickAction: ClickAction.playPause,
      showControlsAlways: true,
      videoUrl: widget.videoUrlBuilder(item),
      sharedMuted: _sharedMuted,
      videoId: widget.videoIdBuilder?.call(item),
      videoTitle: widget.videoTitleBuilder?.call(item),
      videoCategory: widget.videoCategory,
      showProgress: widget.showProgress,
      allowSeek: widget.allowSeek,
      overlay: _buildOverlay(context, item, index),
      onPlay: () {
        if (!_isVisiblePage(index) || widget.onVideoStarted == null) return;
        widget.onVideoStarted!(item, index);
      },
      onPositionChanged: (position) {
        if (!_isVisiblePage(index)) return;
        widget.onPositionChanged?.call(item, position);
      },
      onPlayPauseChanged: (playing) {
        if (!_isVisiblePage(index)) return;
        widget.onPlayPauseChanged?.call(item, playing);
      },
      onDurationChanged: (duration) {
        if (!_isVisiblePage(index)) return;
        widget.onDurationChanged?.call(duration);
        widget.onItemDurationChanged?.call(item, duration);
      },
      onFullscreenChanged: widget.onFullscreenChanged,
      loadingIndicator: widget.itemLoadingIndicator,
      onCompleted: () {
        if (!_isVisiblePage(index)) return;
        widget.onVideoCompleted?.call(item);
        if (!widget.autoPlayNext) return;
        final currentPage = _pageController.page?.round() ?? 0;
        final nextIndex = currentPage + 1;
        final loadedItems = <T>[];
        final state = widget.controller.value;

        try {
          final dynamicState = state as dynamic;
          if (dynamicState.items != null) {
            loadedItems.addAll(List<T>.from(dynamicState.items));
          }
        } catch (_) {}

        if (loadedItems.isEmpty) return;

        if (nextIndex < loadedItems.length) {
          _pageController.animateToPage(
            nextIndex,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );

          if (widget.onItemChanged != null) {
            widget.onItemChanged!(loadedItems[nextIndex], nextIndex);
          }
        }
      },
    );
  }

  bool _isVisiblePage(int index) {
    if (!_pageController.hasClients) return index == 0;
    return _pageController.page?.round() == index;
  }

  Widget _buildOverlay(BuildContext context, T item, int index) {
    if (widget.overlayBuilder == null) return SizedBox.shrink();
    if (widget.expandOverlay) {
      return SizedBox.expand(
        child: widget.overlayBuilder?.call(context, item, index),
      );
    }

    final progressBarPadding = widget.showProgress ? 80.0 : 0.0;

    return Align(
        alignment: Alignment.bottomRight,
        child: Wrap(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              padding: EdgeInsets.fromLTRB(
                16,
                120,
                16,
                (widget.bottomPadding ?? (20 + (Get.width * 0.16))) +
                    progressBarPadding,
              ),
              width: double.infinity,
              child: widget.overlayBuilder?.call(context, item, index),
            ),
          ],
        ));
  }
}
