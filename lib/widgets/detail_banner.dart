import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../l10n/localization_context.dart';
import '../theme/app_theme.dart';

/// Full-bleed cover banner used by book/manga detail screens — the cover
/// fills the width with a bottom gradient and the title/back button
/// floating over it, instead of a small centered cover under a plain AppBar.
/// The favorite heart and overflow (remove) menu only show once the title
/// is actually in the library, matching Showtime's banner.
class DetailBanner extends StatelessWidget {
  final String? coverUrl;
  final String title;
  final bool inLibrary;
  final bool favorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback onRemove;
  final IconData placeholderIcon;

  const DetailBanner({
    super.key,
    required this.coverUrl,
    required this.title,
    required this.inLibrary,
    required this.favorite,
    required this.onToggleFavorite,
    required this.onRemove,
    this.placeholderIcon = Icons.menu_book,
  });

  Widget _placeholder(BuildContext context) => Container(
        color: context.colorSurfaceVariant,
        alignment: Alignment.center,
        child: Icon(placeholderIcon, color: context.colorTextSecondary, size: 56),
      );

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: Stack(
        fit: StackFit.expand,
        children: [
          coverUrl != null
              ? CachedNetworkImage(
                  imageUrl: coverUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (context, url, error) => _placeholder(context),
                )
              : _placeholder(context),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x1A000000), Color(0xD9000000)],
              ),
            ),
          ),
          Positioned(
            top: 4,
            left: 4,
            right: 4,
            child: SafeArea(
              bottom: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Row(
                    children: [
                      if (inLibrary)
                        IconButton(
                          icon: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                            child: Icon(
                              favorite ? Icons.favorite : Icons.favorite_border,
                              key: ValueKey(favorite),
                              color: favorite ? Colors.redAccent : Colors.white,
                            ),
                          ),
                          onPressed: onToggleFavorite,
                        ),
                      if (inLibrary)
                        PopupMenuButton<void>(
                          icon: const Icon(Icons.more_vert, color: Colors.white),
                          color: context.colorSurface,
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              onTap: onRemove,
                              child: Text(context.tr('detail.removeFromLibrary')),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
