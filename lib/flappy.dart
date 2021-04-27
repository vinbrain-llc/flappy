library flappy;

import 'package:feedback/feedback.dart';
import 'package:flappy/shake_detector.dart';
import 'package:flutter/material.dart';

class FlappyFeedback extends StatefulWidget {
  final Widget child;
  final Function(BuildContext context) listener;

  FlappyFeedback({required this.listener, required this.child});

  @override
  _FlappyFeedbackState createState() => _FlappyFeedbackState((context) => {
        BetterFeedback.of(context)!.show((feedback, feedbackScreenshot) {
          alertFeedbackFunction(
            context,
            feedback,
            feedbackScreenshot,
          );
        })
      });
}

class _FlappyFeedbackState extends State<FlappyFeedback> {
  final Function(BuildContext) _listener;
  late ShakeDetector _shakeDetector;

  _FlappyFeedbackState(this._listener) {
    _shakeDetector = ShakeDetector(() => _listener.call(context));
  }

  @override
  Widget build(BuildContext context) {
    return BetterFeedback(child: widget.child);
  }

  @override
  void dispose() {
    _shakeDetector.stop();
    super.dispose();
  }
}
