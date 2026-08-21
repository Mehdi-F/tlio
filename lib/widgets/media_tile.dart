import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Card-style row for a book/manga list — rounded thumbnail on a surface
/// background, bold title, secondary subtitle. Replaces the bare ListTile
/// used across Books & BD, Manga, and Explorer's search results.
class MediaTile extends StatelessWidget {
  final String? coverUrl;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final IconData placeholderIcon;
  final bool dimmed;

  const MediaTile({
    super.key,
    required this.coverUrl,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.placeholderIcon = Icons.menu_book,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: dimmed ? 0.6 : 1,
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: context.colorSurface,
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: SizedBox(
                  width: 48,
                  height: 68,
                  child: coverUrl != null
                      ? CachedNetworkImage(
                          imageUrl: coverUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Container(
                            color: context.colorSurfaceVariant,
                            alignment: Alignment.center,
                            child: Icon(placeholderIcon, color: context.colorTextSecondary, size: 20),
                          ),
                        )
                      : Container(
                          color: context.colorSurfaceVariant,
                          alignment: Alignment.center,
                          child: Icon(placeholderIcon, color: context.colorTextSecondary, size: 20),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: TextStyle(color: context.colorTextSecondary, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}
