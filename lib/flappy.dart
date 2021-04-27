library flappy;

import 'package:flappy/shake_listener.dart';
import 'package:flutter/material.dart';

class FlappyFeedback extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      child: ShakeListener(
          listener: (context) => print("alo"), child: Container()),
    );
  }
}
