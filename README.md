# TLIO — The Library Is Open

Reading tracker for books, BD and manga, shared by two people. Flutter,
Firebase Auth (Google sign-in) + Firestore, Google Books for books/BD,
AniList for manga.

Web: https://mehdi-f.github.io/tlio/ — every push to `main` builds and
deploys to the `gh-pages` branch via GitHub Actions.

## Development

The Google Books key is read via
`String.fromEnvironment('GOOGLE_BOOKS_API_KEY')`, so it is baked in at
compile time. A build started without it falls back to unauthenticated
Google Books calls, which share a tiny anonymous quota — searches then fail
with 429s under ordinary use, with nothing at runtime explaining why. Use the
build script rather than calling `flutter build` directly:

```
cp dart_define.example.json dart_define.json   # then paste the API key
flutter pub get

./scripts/build.ps1 -Target run                # run on a connected device
./scripts/build.ps1 -Target apk -Install       # release APK, installed via adb
./scripts/build.ps1 -Target web                # release web bundle
```

`dart_define.json` is gitignored. CI passes the same key from the
`GOOGLE_BOOKS_API_KEY` repo secret, so deploys need no local setup.

`firestore.rules` is gitignored too (it holds the allowlisted emails) and is
deployed with `firebase deploy --only firestore:rules`.
