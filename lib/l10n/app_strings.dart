class AppStrings {
  static const Map<String, Map<String, String>> _translations = {
    'fr': {
      // Navigation
      'nav.books': 'Livres & BD',
      'nav.manga': 'Manga',
      'nav.explore': 'Explorer',
      'nav.profile': 'Profil',

      // Common
      'common.ok': 'OK',
      'common.cancel': 'Annuler',
      'common.save': 'Enregistrer',
      'common.delete': 'Supprimer',
      'common.retry': 'Réessayer',
      'common.done': 'Terminé',
      'common.edit': 'Modifier',
      'common.yes': 'Oui',
      'common.no': 'Non',
      'common.loadMore': 'Charger plus',

      // Login
      'login.tagline': 'Ta bibliothèque, ouverte',
      'login.signInWithGoogle': 'Se connecter avec Google',

      // Books & BD
      'books.title': 'Livres & BD',
      'books.filterAll': 'Tous',
      'books.filterBooks': 'Livres',
      'books.filterComics': 'BD',
      'books.empty': 'Aucun titre dans ta bibliothèque.',
      'books.pagesProgress': 'pages lues',

      // Manga
      'manga.title': 'Manga',
      'manga.empty': 'Aucun manga dans ta bibliothèque.',
      'manga.volumesProgress': 'tomes lus',
      'manga.showHistory': 'Voir l\'historique',
      'manga.hideHistory': 'Masquer l\'historique',
      'manga.history': 'HISTORIQUE DE LECTURE',

      // Explorer
      'explorer.searchBooks': 'Rechercher un livre ou une BD...',
      'explorer.searchManga': 'Rechercher un manga...',
      'explorer.toggleBooks': 'Livres & BD',
      'explorer.toggleManga': 'Manga',
      'explorer.noResults': 'Aucun résultat.',
      'explorer.searchFailed': 'La recherche a échoué. Vérifie ta connexion.',

      // Detail
      'detail.addToLibrary': 'Ajouter à ma bibliothèque',
      'detail.removeFromLibrary': 'Retirer de la bibliothèque',
      'detail.status': 'Statut',
      'detail.statusReading': 'En cours',
      'detail.statusCompleted': 'Terminé',
      'detail.statusPlanToRead': 'À lire',
      'detail.by': 'de',

      // Profile
      'profile.title': 'Profil',
      'profile.booksRead': 'livres lus',
      'profile.comicsRead': 'BD lues',
      'profile.mangaRead': 'manga lus',
      'profile.signOut': 'Déconnexion',
    },
    'en': {
      'nav.books': 'Books & Comics',
      'nav.manga': 'Manga',
      'nav.explore': 'Explore',
      'nav.profile': 'Profile',

      'common.ok': 'OK',
      'common.cancel': 'Cancel',
      'common.save': 'Save',
      'common.delete': 'Delete',
      'common.retry': 'Retry',
      'common.done': 'Done',
      'common.edit': 'Edit',
      'common.yes': 'Yes',
      'common.no': 'No',
      'common.loadMore': 'Load more',

      'login.tagline': 'Your library, open',
      'login.signInWithGoogle': 'Sign in with Google',

      'books.title': 'Books & Comics',
      'books.filterAll': 'All',
      'books.filterBooks': 'Books',
      'books.filterComics': 'Comics',
      'books.empty': 'Nothing in your library yet.',
      'books.pagesProgress': 'pages read',

      'manga.title': 'Manga',
      'manga.empty': 'No manga in your library yet.',
      'manga.volumesProgress': 'volumes read',
      'manga.showHistory': 'Show history',
      'manga.hideHistory': 'Hide history',
      'manga.history': 'READING HISTORY',

      'explorer.searchBooks': 'Search for a book or comic...',
      'explorer.searchManga': 'Search for a manga...',
      'explorer.toggleBooks': 'Books & Comics',
      'explorer.toggleManga': 'Manga',
      'explorer.noResults': 'No results.',
      'explorer.searchFailed': 'Search failed. Check your connection.',

      'detail.addToLibrary': 'Add to my library',
      'detail.removeFromLibrary': 'Remove from library',
      'detail.status': 'Status',
      'detail.statusReading': 'Reading',
      'detail.statusCompleted': 'Completed',
      'detail.statusPlanToRead': 'Plan to read',
      'detail.by': 'by',

      'profile.title': 'Profile',
      'profile.booksRead': 'books read',
      'profile.comicsRead': 'comics read',
      'profile.mangaRead': 'manga read',
      'profile.signOut': 'Sign out',
    },
  };

  static String get(String key, {String language = 'fr'}) {
    return _translations[language]?[key] ?? key;
  }
}
