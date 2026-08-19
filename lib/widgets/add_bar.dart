import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Persistent bottom "+ Ajouter..." bar shown on detail screens while the
/// title isn't yet in the library, matching Showtime's AddBar.
class AddBar extends StatelessWidget {
  final String label;
  final Future<void> Function() onTap;

  const AddBar({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Material(
        color: AppColors.accent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add, color: Colors.black),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
