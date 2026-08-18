import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../l10n/localization_context.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'The Library Is Open',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.accent, letterSpacing: 0.3),
            ),
            const SizedBox(height: 8),
            Text(context.tr('login.tagline'), style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 40),
            FilledButton.icon(
              onPressed: () => context.read<AuthProvider>().signInWithGoogle(),
              icon: const Icon(Icons.login),
              label: Text(context.tr('login.signInWithGoogle')),
            ),
          ],
        ),
      ),
    );
  }
}
