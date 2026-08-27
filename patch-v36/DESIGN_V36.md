# Saleh v36

The approved concept is implemented as three Flutter environments, retaining the
user's original Saleh animations and v35 tracing geometry/frame.

- Home courtyard: resume activity, three destinations, age-appropriate daily suggestion.
- Garden: alif activities; other letters explicitly coming soon.
- Quiet classroom: new background behind the existing interactive lesson board.
- Local child profiles, isolated lesson keys, lossless legacy-profile migration.
- Parent gate and recorded activity/attempt indicators (not speech mastery claims).
- Review of reached material and achievements based on saved activities.
- Gesture priority expires after 0.9–1.45 seconds; real narration then controls Talking.
- Original Talking clip retained. Derived speech animation uses frames 12–54,
  excluding closed-mouth lead/tail; 43 frames / 2838ms. No character repainting.
- Fixed notification during locked lesson widget-tree transitions.
- Completion save is awaited before leaving the success screen.

## Generated background assets

Built-in image_gen tool, using the approved saleh-design-concept.png as a style
reference; three independent generations. Workspace assets:

- assets/backgrounds/courtyard_v36.png
- assets/backgrounds/garden_v36.png
- assets/backgrounds/classroom_v36.png

Shared final prompt: Production game background asset for children's app, ONE
full-bleed landscape 16:9 image, not a collage. Reference is style and environment
reference only. Match reference polished gentle 3D storybook, soft daytime light,
pastel lavender mint cream, quiet negative space for Flutter UI. Absolutely NO
words, letters, UI, cards, buttons, logos, frames, borders, watermarks or people.
Background only.

Scene prompts:
1. Top concept's sunny Arabian courtyard, cream arches far edges, sky, distant
   palm trees, lavender flowers corners, wide empty stone floor and low-detail center.
2. Bottom-right environment, winding pale stepping stones, grass, flowers edges,
   trees, distant gazebo; foreground clear for interactive letters, no stations/characters.
3. Bottom-left quiet cream classroom, blurred bookcase far right/window left,
   empty center wall, wooden tabletop bottom 22%; no board/paper/letters/person.

## Verification

world_v36_test.dart tests legacy migration, independent child progress, actual
animated WebP decoding, live lesson gesture-to-Talking renderer transitions,
scene changes, and landscape layouts. Visual goldens are local-only. No on-device
lip-sync claim: mouth motion follows the narration interval, not phoneme alignment.
