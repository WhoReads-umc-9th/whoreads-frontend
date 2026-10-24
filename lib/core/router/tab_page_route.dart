import 'package:flutter/material.dart';

/// Sibling tabs replace one another without a page drill-in animation.
class TabPageRoute<T> extends PageRouteBuilder<T> {
  TabPageRoute({required WidgetBuilder builder})
    : super(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (context, animation, secondaryAnimation) =>
            builder(context),
      );
}
