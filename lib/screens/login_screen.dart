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
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.3),
            radius: 1.1,
            colors: [context.colorSurface, context.colorBackground],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/icon/icon_foreground.png', width: 96, height: 96),
              const SizedBox(height: 20),
              const Text(
                'The Library Is Open',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppColors.accent, letterSpacing: 0.3),
              ),
              const SizedBox(height: 8),
              Text(context.tr('login.tagline'), style: TextStyle(color: context.colorTextSecondary, fontSize: 14)),
              const SizedBox(height: 40),
              FilledButton.icon(
                onPressed: () => context.read<AuthProvider>().signInWithGoogle(),
                icon: const Icon(Icons.login),
                label: Text(context.tr('login.signInWithGoogle')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
