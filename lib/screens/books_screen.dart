import 'package:flutter/material.dart';
import '../l10n/localization_context.dart';

class BooksScreen extends StatelessWidget {
  const BooksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(context.tr('books.title'))));
  }
}
