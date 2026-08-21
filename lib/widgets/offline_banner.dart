import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/localization_context.dart';
import '../providers/connectivity_provider.dart';
import '../theme/app_theme.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final isOnline = context.watch<ConnectivityProvider>().isOnline;
    if (isOnline) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: AppColors.accent,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const SizedBox(width: 12),
            const Icon(Icons.cloud_off, size: 14, color: Colors.black),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                context.tr('common.offline'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}
