import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SkeletonBox extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(6)),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: context.colorSurfaceVariant, borderRadius: borderRadius),
    );
  }
}

class PosterGridSkeleton extends StatelessWidget {
  final double childAspectRatio;

  const PosterGridSkeleton({super.key, this.childAspectRatio = 0.67});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: childAspectRatio,
      ),
      itemCount: 12,
      itemBuilder: (context, i) => const SkeletonBox(width: double.infinity, height: double.infinity),
    );
  }
}

class MediaListSkeleton extends StatelessWidget {
  final int itemCount;

  const MediaListSkeleton({super.key, this.itemCount = 8});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: itemCount,
      itemBuilder: (context, i) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            const SkeletonBox(width: 56, height: 78),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  SkeletonBox(width: double.infinity, height: 14),
                  SizedBox(height: 8),
                  SkeletonBox(width: 120, height: 12),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DetailScreenSkeleton extends StatelessWidget {
  const DetailScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}
