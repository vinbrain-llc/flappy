library flappy;

import 'package:flappy/shake_listener.dart';
import 'package:flutter/material.dart';

class FlappyFeedback extends StatelessWidget {
  final Widget child;
  final Function(BuildContext context) listener;

  FlappyFeedback({required this.listener, required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      child: ShakeListener(listener: listener, child: child),
    );
  }
}
