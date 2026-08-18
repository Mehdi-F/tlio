import 'package:flutter/material.dart';
import '../l10n/localization_context.dart';

class MangaScreen extends StatelessWidget {
  const MangaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(context.tr('manga.title'))));
  }
}
