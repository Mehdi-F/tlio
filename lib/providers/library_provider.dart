import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/library_item.dart';
import '../services/library_service.dart';

class LibraryProvider extends ChangeNotifier {
  final LibraryService _libraryService;
  StreamSubscription<List<LibraryItem>>? _subscription;
  List<LibraryItem> _items = [];
  String? _uid;
  bool _loaded = false;

  LibraryProvider(this._libraryService);

  List<LibraryItem> get items => _items;

  bool get isLoaded => _loaded;

  void watch(String uid) {
    if (_uid == uid) return;
    _uid = uid;
    _loaded = false;
    _subscription?.cancel();
    _subscription = _libraryService.watchLibrary(uid).listen((items) {
      _items = items;
      _loaded = true;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
