import 'package:flutter/material.dart';

/// Versioned, original 3D artwork; navigation arrows remain simple and legible.
enum Toy {
  book,
  mic,
  pencil,
  puzzle,
  trophy,
  album,
  coins,
  home,
  headphones,
  cards,
  flower,
  lock
}

class ToyIcon extends StatelessWidget {
  const ToyIcon(this.toy, {super.key, this.size = 56});
  final Toy toy;
  final double size;
  @override
  Widget build(BuildContext context) {
    const centersX = [.166, .389, .609, .833];
    const centersY = [.22, .515, .80];
    const cropWidth = .235;
    const cropHeight = cropWidth * 4 / 3;
    final left = centersX[toy.index % 4] - cropWidth / 2;
    final top = centersY[toy.index ~/ 4] - cropHeight / 2;
    return ExcludeSemantics(
        child: ClipRRect(
      borderRadius: BorderRadius.circular(size * .20),
      child: SizedBox.square(
          dimension: size,
          child: Stack(children: [
            Positioned(
                left: -left * size / cropWidth,
                top: -top * size / cropHeight,
                width: size / cropWidth,
                height: size / cropHeight,
                child:
                    Image.asset('assets/ui/icons_v38.png', fit: BoxFit.fill)),
          ])),
    ));
  }
}

Toy toyForIcon(IconData icon) {
  if ([Icons.mic_rounded, Icons.mic_outlined].contains(icon)) return Toy.mic;
  if ([Icons.home_rounded].contains(icon)) return Toy.home;
  if ([Icons.lock_outline, Icons.lock_rounded].contains(icon)) return Toy.lock;
  if ([Icons.extension_rounded].contains(icon)) return Toy.puzzle;
  if ([Icons.edit_rounded, Icons.draw_rounded].contains(icon)) {
    return Toy.pencil;
  }
  if ([Icons.workspace_premium_rounded, Icons.emoji_events_rounded]
      .contains(icon)) {
    return Toy.trophy;
  }
  if ([Icons.hearing_rounded].contains(icon)) return Toy.headphones;
  if ([Icons.local_florist_rounded, Icons.explore_rounded].contains(icon)) {
    return Toy.flower;
  }
  return Toy.book;
}
