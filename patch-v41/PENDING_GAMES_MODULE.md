# Approved games module for future Saleh releases

User decision: adopt Saleh-Games-v40-Module.zip in future app releases.
Current status (v41 integration, 2026-08-28): merged into the current app and locally tested; IPA build and device installation tracked in RELEASE_V41.md. The original adoption-only notes below are historical.

## Package

- Source: C:/Users/FIN/Documents/Codex/2026-08-28/new-chat/outputs/Saleh-Games-v40-Module.zip
- Staged copy: pending_modules/saleh-games-v40/Saleh-Games-v40-Module.zip
- ZIP size: 3808355 bytes; 16 files; 4165056 uncompressed bytes.
- SHA-256: fcb65186719d06e8531b7ad26879490d9a761fce2831f465afa7e054615ebc5c
- Inspected ZIP inventory, GAMES_V40.md, pubspec.yaml, game_store.dart, and selected catalog/hub/navigation code.
- Catalog has 36 GameSpec definitions across words, numbers, and thinking.
- Three rounds per game according to the package notes; not 108 unique activities.

## Integration for the next app release

1. Read GAMES_V40.md and inspect the latest app source before merging.
2. Validate archive entry paths before extracting into an isolated directory, never directly over the live project.
3. Merge lib/features/games/, assets/games/, both included test files, and the module documentation.
4. Add assets/games/ to the current pubspec.yaml without replacing its other contents or forcing build number 40.
5. In the latest world_screen.dart, integrate the GamesHub import and _review entry point. Do not overwrite the entire screen from the ZIP.
6. Preserve the existing alif lesson, tracing, character behavior, approved audio, profile storage, and the three older review games.
7. Keep storage key games_v1_<childId> and stable reward IDs game:worlds:<gameId>, 15 points once per child/game.
8. Coordinate shared files and choose the next available release number with the integration owner. Package v40 is a module label, not proof that the shared app is already v40.
9. Run analysis, old regression tests, games_worlds_test.dart, and visual review for games_gallery_visual_test.dart. Check small screens, retries, child isolation, and duplicate rewards.
10. After actual app changes, build and verify an IPA as requested by the user. Do not launch duplicate builds or claim installation without confirmation of success.

## Known limits in the package

- New game instructions are text only; new per-game narration has not been supplied.
- listen_find reuses the existing lion audio in its three rounds.
- Several activities have limited/repeated challenge content.
- Resume is from the start of the unfinished round, not every intermediate move.
- No on-device performance, audio, drag, or installation result was verified in this adoption turn.
- Future narration must follow VOICEOVER_SETTINGS.md; tracing must follow WRITING_REFERENCE.md.
- The art prompt document inside this ZIP is GAMES_ART_PROMPTS.md, despite the alternative filename mentioned in GAMES_V40.md.

At original adoption, only the archive and documentation were staged. During v41 integration, new games code/assets/tests and the two shared entry points were merged, preserving prior app data.
