import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/constants.dart';

import '../theme/app_theme.dart';

/// Celebration shown when a title is finished: the cover in a medallion that
/// springs in over an expanding ring and a bloom of particles in the accent
/// palette. Ported from Showtime, where it marks a series finished for good.
/// Plays a [CompletionCelebration] in the root overlay, so it sits above
/// everything on screen — modal sheets included. Showtime first painted it
/// in the page's own Stack, where an open episode sheet covered it.
class CompletionCelebrator {
  CompletionCelebrator({required TickerProvider vsync})
    : _controller = AnimationController(
        vsync: vsync,
        duration: AppConstants.celebrationDuration,
      );

  final AnimationController _controller;
  OverlayEntry? _entry;

  void play(BuildContext context, {required String label, String? coverUrl}) {
    _remove();
    final entry = OverlayEntry(
      builder: (_) => CompletionCelebration(
        controller: _controller,
        label: label,
        coverUrl: coverUrl,
      ),
    );
    _entry = entry;
    Overlay.of(context, rootOverlay: true).insert(entry);
    HapticFeedback.mediumImpact();
    _controller.forward(from: 0).whenComplete(_remove);
  }

  void _remove() {
    _entry?.remove();
    _entry = null;
  }

  void dispose() {
    _remove();
    _controller.dispose();
  }
}

class CompletionCelebration extends StatelessWidget {
  final AnimationController controller;

  /// The finished title's cover, shown in the medallion. Falls back to a
  /// check mark when there's no cover.
  final String? coverUrl;

  /// Already translated, e.g. "Lecture terminée" or "Série terminée".
  final String label;

  const CompletionCelebration({
    super.key,
    required this.controller,
    required this.label,
    this.coverUrl,
  });

  static final List<_Particle> _particles = _buildParticles();

  static List<_Particle> _buildParticles() {
    // Fixed seed: the burst should look designed, not different every time.
    final random = Random(20260927);
    return List.generate(22, (i) {
      final angle = (i / 22) * 2 * pi + random.nextDouble() * 0.28;
      return _Particle(
        angle: angle,
        distance: 90 + random.nextDouble() * 80,
        size: 2 + random.nextDouble() * 3.5,
        delay: random.nextDouble() * 0.12,
        shade: random.nextDouble(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Played from the root overlay, which sits above every Material — with
    // no DefaultTextStyle there, the label fell back to Flutter's
    // "missing Material" style: yellow double underline. A transparent
    // Material restores the theme's text style without painting anything.
    return IgnorePointer(
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final t = controller.value;
            if (t == 0) return const SizedBox.shrink();

            final fadeOut =
                1 -
                Curves.easeIn.transform(((t - 0.82) / 0.18).clamp(0.0, 1.0));
            final badgeScale = Curves.elasticOut.transform(
              (t / 0.55).clamp(0.0, 1.0),
            );
            final labelOpacity = Curves.easeOut.transform(
              ((t - 0.22) / 0.25).clamp(0.0, 1.0),
            );

            return Opacity(
              opacity: fadeOut,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _BloomPainter(
                        progress: t,
                        particles: _particles,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Transform.scale(
                        scale: badgeScale,
                        child: Container(
                          width: 104,
                          height: 104,
                          decoration: BoxDecoration(
                            color: AppColors.accent,
                            shape: BoxShape.circle,
                            // White on dark, black on light: the medallion has
                            // to read against both the page and whatever the
                            // poster's edges happen to be.
                            border: Border.all(
                              color: context.colorTextPrimary,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.accent.withValues(alpha: 0.45),
                                blurRadius: 28,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: coverUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: coverUrl!,
                                    fit: BoxFit.cover,
                                    errorWidget: (context, url, error) =>
                                        const Icon(
                                          Icons.check_rounded,
                                          color: Colors.black,
                                          size: 46,
                                        ),
                                  )
                                : const Icon(
                                    Icons.check_rounded,
                                    color: Colors.black,
                                    size: 46,
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Opacity(
                        opacity: labelOpacity,
                        // Rises as it fades in, so it lands under the medallion
                        // instead of just appearing there.
                        child: Transform.translate(
                          offset: Offset(0, 10 * (1 - labelOpacity)),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.accent.withValues(
                                    alpha: 0.35,
                                  ),
                                  blurRadius: 18,
                                  spreadRadius: 1,
                                ),
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 9,
                              ),
                              child: Text(
                                label,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Particle {
  final double angle;
  final double distance;
  final double size;
  final double delay;

  /// 0 → accent, 1 → a paler gold, so the bloom has depth without leaving
  /// the palette.
  final double shade;

  const _Particle({
    required this.angle,
    required this.distance,
    required this.size,
    required this.delay,
    required this.shade,
  });
}

class _BloomPainter extends CustomPainter {
  final double progress;
  final List<_Particle> particles;

  _BloomPainter({required this.progress, required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Two staggered rings read as a single pulse with depth.
    for (var i = 0; i < 2; i++) {
      final ringT = ((progress - i * 0.09) / 0.6).clamp(0.0, 1.0);
      if (ringT <= 0 || ringT >= 1) continue;
      final eased = Curves.easeOutCubic.transform(ringT);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * (1 - eased) + 0.5
        ..color = AppColors.accent.withValues(alpha: (1 - eased) * 0.7);
      canvas.drawCircle(center, 30 + eased * 130, paint);
    }

    for (final p in particles) {
      final pt = ((progress - p.delay) / (0.85 - p.delay)).clamp(0.0, 1.0);
      if (pt <= 0) continue;
      final eased = Curves.easeOutCubic.transform(pt);
      final radius = 26 + eased * p.distance;
      // A touch of gravity so the bloom settles instead of floating away.
      final drop = 34 * pt * pt;
      final offset = Offset(
        center.dx + cos(p.angle) * radius,
        center.dy + sin(p.angle) * radius + drop,
      );
      final paint = Paint()
        ..color = Color.lerp(
          AppColors.accent,
          const Color(0xFFFFE9A8),
          p.shade,
        )!.withValues(alpha: (1 - pt * pt).clamp(0.0, 1.0));
      canvas.drawCircle(offset, p.size * (1 - pt * 0.45), paint);
    }
  }

  @override
  bool shouldRepaint(_BloomPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
