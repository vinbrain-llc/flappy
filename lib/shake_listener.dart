import 'package:flutter/widgets.dart';
import 'shake_detector.dart';

class ShakeListener extends StatefulWidget {
  final Function(BuildContext) listener;
  final Widget child;

  ShakeListener({@required this.listener, @required this.child});

  @override
  _ShakeListenerState createState() {
    return _ShakeListenerState(listener);
  }
}

class _ShakeListenerState extends State<ShakeListener> {
  final Function(BuildContext) _listener;
  ShakeDetector _shakeDetector;

  _ShakeListenerState(this._listener) {
    _shakeDetector = ShakeDetector(() => _listener.call(context));
  }

  @override
  Widget build(BuildContext context) => widget.child;

  @override
  void dispose() {
    _shakeDetector.stop();
    super.dispose();
  }
}
