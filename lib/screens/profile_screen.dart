import 'package:flutter/material.dart';
import '../l10n/localization_context.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(context.tr('profile.title'))));
  }
}
