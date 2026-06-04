import 'dart:io';

import 'package:flutter/material.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:share_plus/share_plus.dart';

class QuickPlayerOverlay extends StatefulWidget {
  const QuickPlayerOverlay({
    super.key,
    required this.title,
    required this.tagline,
    this.shortDescription,
    this.description,
    this.isLiked = false,
    this.onLikePressed,
    this.shareUrl,
    this.shareSubject,
    this.showLikeButton = true,
    this.hideOverlay = false,
  });

  final String title;
  final String tagline;
  final String? shortDescription;
  final String? description;
  final bool isLiked;
  final Function()? onLikePressed;
  final String? shareUrl;
  final String? shareSubject;

  /// Whether to show the like button
  final bool showLikeButton;

  /// Whether to hide the entire overlay (for fullscreen mode)
  final bool hideOverlay;

  @override
  State<QuickPlayerOverlay> createState() => _QuickPlayerOverlayState();
}

class _QuickPlayerOverlayState extends State<QuickPlayerOverlay> {
  bool _isDescriptionExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.hideOverlay) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        Expanded(child: _detailsSection()),
        const SizedBox(width: 16),
        _sideActions(),
      ],
    );
  }

  Widget _detailsSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.tagline,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        if ((widget.shortDescription ?? '').isNotEmpty)
          Text(
            _stripHtml(widget.shortDescription.toString()),
            style: const TextStyle(color: Colors.white70, fontSize: 14),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        const SizedBox(height: 4),
        if ((widget.description ?? '').isNotEmpty)
          Builder(
            builder: (context) {
              final cleanDescription = _stripHtml(widget.description!);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _isDescriptionExpanded = !_isDescriptionExpanded;
                  });
                },
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    children: [
                      TextSpan(
                        text: _isDescriptionExpanded
                            ? cleanDescription
                            : (cleanDescription.length > 100
                                ? '${cleanDescription.substring(0, 100)}...'
                                : cleanDescription),
                      ),
                      if (!_isDescriptionExpanded &&
                          cleanDescription.length > 100)
                        const TextSpan(
                          text: ' Read more',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (_isDescriptionExpanded)
                        const TextSpan(
                          text: ' Show less',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _sideActions() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        if (widget.showLikeButton && widget.onLikePressed != null)
          InkWell(
            onTap: widget.onLikePressed,
            child: Icon(
              widget.isLiked ? Icons.favorite : Icons.favorite_border,
              color: widget.isLiked ? Colors.redAccent : Colors.white,
              size: 30,
            ),
          ),
        if (widget.showLikeButton && widget.onLikePressed != null)
          const SizedBox(height: 24),
        _ShareIconButton(
          url: widget.shareUrl ?? '',
          subject: widget.shareSubject ?? '',
        ),
      ],
    );
  }
}

String _stripHtml(String htmlString) {
  final replaced = htmlString.replaceAll(RegExp(r'<br\s*/?>'), '\n');
  final document = html_parser.parse(replaced);
  return html_parser.parse(document.body!.text).documentElement!.text;
}

class _ShareIconButton extends StatelessWidget {
  const _ShareIconButton({required this.url, required this.subject});
  final String url;
  final String subject;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: url.isEmpty
          ? null
          : () {
              final suffix = Platform.isAndroid
                  ? '&utm_source=app_share&utm_medium=android_shared_link&utm_campaign=user_shared_link'
                  : '?utm_source=app_share&utm_medium=ios_shared_link&utm_campaign=user_shared_link';
              SharePlus.instance.share(
                ShareParams(text: url + suffix, subject: subject),
              );
            },
      child: const Icon(Icons.share, color: Colors.white, size: 22),
    );
  }
}
