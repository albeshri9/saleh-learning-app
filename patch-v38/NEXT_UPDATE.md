# Implemented in v38 — user request 2026-08-28

The recording is now bundled as assets/audio/assessment_applause_user.mp3, with independent playback at 0.65 against narrator 1.0. Measurements, limits and verification details are in DESIGN_V38.md. The original pending asset remains preserved. Notes below record the original request, not additional unfinished implementation.

- Use the user-supplied encouragement/applause recording at the end of the assessment, alongside the narrator and audibly quieter than the narrator.
- Original: `C:/Users/FIN/Downloads/Music/content.mp3`.
- Preserved byte-for-byte at `pending_assets/assessment_applause_user.mp3`. This pending folder is not bundled into the current app.
- Replace the current generated `assets/audio/applause.wav` usage in `InteractionAudio` when implementing the next app update; do not layer both applause recordings.
- Keep the narrator on its independent player. Start effect gain around 0.20 relative to the narrator's normal playback as a tuning baseline, then verify the perceived mix with the actual recording; the narrator must remain clear and louder. Do not reduce narrator volume to make room for the effect.
- Play once on entering the post-assessment success scene, not after every answer. Stop on leaving the scene and prevent duplicate playback.
- Preserve the original recording; add the selected asset to the next build and verify packaging and overlapping audio before IPA delivery.
- User requested this for the next update. No app runtime change, build, push or installation is being performed just to stage this request.
- The previous twenty development suggestions remain proposals, not blanket approval to implement them.
