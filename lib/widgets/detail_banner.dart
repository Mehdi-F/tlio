import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Full-bleed cover banner used by book/manga detail screens — the cover
/// fills the width with a bottom gradient and the title/back button
/// floating over it, instead of a small centered cover under a plain AppBar.
class DetailBanner extends StatelessWidget {
  final String? coverUrl;
  final String title;

  const DetailBanner({super.key, required this.coverUrl, required this.title});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: Stack(
        fit: StackFit.expand,
        children: [
          coverUrl != null
              ? CachedNetworkImage(imageUrl: coverUrl!, fit: BoxFit.cover)
              : Container(color: AppColors.surfaceVariant),
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
            child: SafeArea(
              bottom: false,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).maybePop(),
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
