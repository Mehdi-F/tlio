# The Library Is Open (TLIO) — MVP Design

## Overview

TLIO is a reading tracker for books, comics (BD), and manga — a sister app to
Showtime, reusing its proven Flutter architecture (provider pattern,
progressive bounded-concurrency resolve, skeleton loaders, Firestore-backed
library) but with its own repo, its own Firebase project, its own visual
identity, and its own data sources.

This spec covers the MVP only. Everything Showtime added after its own MVP
(reminders, export, yearly recap, friend comparison, home screen widget) is
explicitly out of scope here and will follow the same brainstorm → spec →
plan → implement cycle as separate follow-up specs, once the MVP is built and
validated.

## Content types

Three types, all present from v1:

- **Livre** (book)
- **BD** (bande dessinée / comic)
- **Manga**

Livres and BD share the same data source and search flow; manga uses a
separate source. Progress is tracked differently per type:

- Livre: pages read / total pages (falls back to a % indicator if a title has
  no known page count)
- BD, Manga: volumes read / total volumes

## Data sources

- **Google Books API** — used for both Livre and BD. No API key required for
  basic search/volume lookup (same no-cost, no-backend shape as TMDB in
  Showtime).
- **AniList API** (GraphQL) — used for Manga. No API key required, generous
  rate limits, strong cover art and volume/chapter metadata.

Two services, mirroring `TmdbService`'s role in Showtime:

- `BookService` — wraps Google Books, serves both Livre and BD lookups.
- `MangaService` — wraps AniList GraphQL queries.

Both implement the same two-tier caching approach already proven in
Showtime's `TmdbService` (in-memory + `SharedPreferences`-backed disk cache
with a TTL) — ported as-is, not redesigned.

## Data model

A single unified `LibraryItem`, mirroring Showtime's `type: 'tv' | 'movie'`
discriminated shape:

```dart
class LibraryItem {
  final String docId;
  final String sourceId;       // Google Books volume ID or AniList media ID
  final String type;           // "book" | "comic" | "manga"
  final String source;         // "googlebooks" | "anilist"
  final String status;         // "reading" | "completed" | "plan_to_read"
  final DateTime addedAt;
  final bool favorite;
  final DateTime? favoritedAt;
  final DateTime? lastActivityAt;

  // Livre only
  final int? pagesRead;
  final int? pagesTotal;

  // BD / Manga only
  final int? volumesRead;
  final int? volumesTotal;

  final int rereadCount;
}
```

Stored at `users/{uid}/library/{docId}`, `docId` built the same way as
Showtime's `LibraryItem.buildDocId` (`'${type}_$sourceId'`).

`LibraryProvider` is a direct port of Showtime's: single Firestore stream
subscription, `isLoaded` flag for the "empty vs not-yet-loaded" distinction,
`items` getter. One instance covers all three content types — no per-type
providers.

## Navigation & screens

Bottom nav, 4 tabs — mirrors Showtime's `[Séries, Films, Explorer, Profil]`
almost exactly:

1. **Livres & BD** — one screen, filter chips at the top (Tous / Livres /
   BD). Direct mirror of `films_screen.dart`'s structure (grid/list toggle,
   progressive resolve, skeleton loader).
2. **Manga** — dedicated screen, mirror of `series_screen.dart` (progress
   tracking, watch-history-equivalent "historique de lecture" section with
   the same toggle-to-expand UX Showtime landed on).
3. **Explorer** — search/discovery. A type toggle (Livres+BD vs Manga)
   determines which service handles the query.
4. **Profil** — stats (books/BD/manga counts, pages/volumes consumed),
   mirror of `profile_screen.dart`'s structure minus the post-MVP features
   listed below.

Detail screens:

- `BookDetailScreen` — serves both Livre and BD (same source, same basic
  shape; progress UI branches on pages vs volumes). Mirror of
  `MovieDetailScreen`.
- `MangaDetailScreen` — volumes/chapters, mirror of `ShowDetailScreen`
  (minus episode-level tracking, which doesn't apply here — volume-level
  only).

## Branding

- Name: **The Library Is Open** (TLIO)
- Palette: warm paper background (`#1C1712` dark / `#FAF6EF` light), terracotta
  accent (`#D97B4F`) — replaces Showtime's black/gold to read as "old-style
  library" rather than "streaming app". Same theme-builder shape as
  Showtime's `buildAppTheme()`, new tokens.
- Logo: placeholder book icon for MVP; a real logo is a later, separate task.

## Error handling

Same approach as Showtime throughout: network calls wrapped in try/catch,
optimistic local state updates with rollback on failure, bounded-concurrency
resolves (`forEachBounded`) so one failed title doesn't block the rest of the
library from rendering. No new error-handling pattern introduced.

## Testing

No automated test suite — matches Showtime's actual established workflow
(manual verification via `flutter analyze` + on-device build/install/test
per feature, not a formal test suite). Same loop will be used for TLIO:
build a feature, install the release APK on-device, verify, then commit.

## Out of scope for this spec

Reminders, library export, "surprise me", yearly recap, friend comparison,
home screen widget — all deferred to their own future specs, built after the
MVP is working end-to-end, in whatever order is decided at that time.
