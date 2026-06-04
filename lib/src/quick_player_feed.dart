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
    this.noMoreItemsIndicator,
    this.firstPageLoadingIndicator,
    this.itemLoadingIndicator,
    this.bottomPadding,
    this.onRefreshData,
    this.onItemChanged,
    this.onVideoStarted,
    this.onDurationChanged,
    this.videoIdBuilder,
    this.videoTitleBuilder,
    this.videoCategory,
    this.showProgress = false,
    this.allowSeek = false,
    this.showRotate = false,
    this.onFullscreenChanged,
  });

  final void Function(T item, int index)? onVideoStarted;

  final void Function(T item, int index)? onItemChanged;

  final Future<void> Function()? onRefreshData;

  final void Function(Duration duration)? onDurationChanged;

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
      videoId: widget.videoIdBuilder?.call(item),
      videoTitle: widget.videoTitleBuilder?.call(item),
      videoCategory: widget.videoCategory,
      showProgress: widget.showProgress,
      allowSeek: widget.allowSeek,
      overlay: _buildOverlay(context, item, index),
      onPlay: () {
        if (widget.onVideoStarted != null) {
          widget.onVideoStarted!(item, index);
        }
      },
      onDurationChanged: widget.onDurationChanged,
      onFullscreenChanged: widget.onFullscreenChanged,
      loadingIndicator: widget.itemLoadingIndicator,
      onCompleted: widget.autoPlayNext
          ? () {
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
            }
          : null,
    );
  }

  Widget _buildOverlay(BuildContext context, T item, int index) {
    if (widget.overlayBuilder == null) return SizedBox.shrink();

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
