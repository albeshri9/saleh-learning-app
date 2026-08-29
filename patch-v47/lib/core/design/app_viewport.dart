import 'package:flutter/material.dart';

/// Learning boards have to keep their controls visible in landscape. Preserve
/// modest system text enlargement, but do not let Android's largest font setting
/// consume the whole board. Never change device density, safe areas or gestures.
class AppViewport extends StatelessWidget {
  const AppViewport({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final availableHeight = media.size.height - media.viewPadding.vertical;
    return MediaQuery.withClampedTextScaling(
      minScaleFactor: 1,
      maxScaleFactor: availableHeight < 500 ? 1.15 : 1.3,
      child: child,
    );
  }
}
