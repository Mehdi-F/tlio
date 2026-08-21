import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/localization_context.dart';
import '../logic/year_recap.dart';
import '../providers/library_provider.dart';
import '../services/book_service.dart';
import '../services/manga_service.dart';
import '../theme/app_theme.dart';

int currentRecapYear() {
  final now = DateTime.now();
  return now.month == 1 ? now.year - 1 : now.year;
}

/// The window during which the recap is relevant enough to surface on the
/// profile screen — Dec 26 through the end of January, mirroring Showtime.
bool isRecapSeason() {
  final now = DateTime.now();
  return (now.month == 12 && now.day >= 26) || now.month == 1;
}

class YearRecapScreen extends StatefulWidget {
  final int year;

  const YearRecapScreen({super.key, required this.year});

  @override
  State<YearRecapScreen> createState() => _YearRecapScreenState();
}

class _YearRecapScreenState extends State<YearRecapScreen> {
  YearRecap? _recap;
  bool _error = false;
  final _controller = PageController();
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = context.read<LibraryProvider>().items;
    final book = context.read<BookService>();
    final manga = context.read<MangaService>();
    try {
      final recap = await computeYearRecap(items: items, bookService: book, mangaService: manga, year: widget.year);
      if (mounted) setState(() => _recap = recap);
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  List<_RecapPage> _buildPages(YearRecap recap, BuildContext context) {
    final pages = <_RecapPage>[
      _RecapPage(title: context.tr('recap.introTitle').replaceAll('{year}', '${recap.year}'), value: '', subtitle: ''),
    ];
    if (recap.titlesFinished > 0) {
      pages.add(_RecapPage(title: '${recap.titlesFinished}', value: '', subtitle: context.tr('recap.titlesFinished')));
    }
    if (recap.mangaVolumesRead > 0) {
      pages.add(_RecapPage(title: '${recap.mangaVolumesRead}', value: '', subtitle: context.tr('recap.mangaVolumesRead')));
    }
    if (recap.pagesRead > 0) {
      pages.add(_RecapPage(title: '${recap.pagesRead}', value: '', subtitle: context.tr('recap.pagesRead')));
    }
    if (recap.itemsAdded > 0) {
      pages.add(_RecapPage(title: '${recap.itemsAdded}', value: '', subtitle: context.tr('recap.itemsAdded')));
    }
    pages.add(_RecapPage(title: context.tr('recap.outro'), value: '', subtitle: ''));
    return pages;
  }

  void _advance(List<_RecapPage> pages) {
    if (_page >= pages.length - 1) {
      Navigator.of(context).pop();
      return;
    }
    _controller.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  void _back() {
    if (_page == 0) return;
    _controller.previousPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final recap = _recap;
    if (_error) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: Text(context.tr('recap.error'), style: const TextStyle(color: AppColors.textSecondary))),
      );
    }
    if (recap == null) {
      return const Scaffold(backgroundColor: AppColors.background, body: Center(child: CircularProgressIndicator()));
    }
    if (recap.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              context.tr('recap.empty'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 16),
            ),
          ),
        ),
      );
    }

    final pages = _buildPages(recap, context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: pages.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) => _RecapPageView(page: pages[i]),
            ),
            Positioned(
              top: 8,
              left: 12,
              right: 12,
              child: Row(
                children: List.generate(
                  pages.length,
                  (i) => Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: i <= _page ? AppColors.accent : AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Positioned.fill(
              top: 40,
              child: Row(
                children: [
                  Expanded(child: GestureDetector(onTap: _back, behavior: HitTestBehavior.translucent)),
                  Expanded(child: GestureDetector(onTap: () => _advance(pages), behavior: HitTestBehavior.translucent)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecapPage {
  final String title;
  final String value;
  final String subtitle;

  _RecapPage({required this.title, required this.value, required this.subtitle});
}

class _RecapPageView extends StatelessWidget {
  final _RecapPage page;

  const _RecapPageView({required this.page});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              page.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.accent,
                fontSize: page.subtitle.isEmpty ? 40 : 56,
                fontWeight: FontWeight.w900,
              ),
            ),
            if (page.subtitle.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                page.subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
