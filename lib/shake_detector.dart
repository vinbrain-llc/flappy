// Copyright 2010 Square, Inc.

import 'dart:async';

import 'package:sensors/sensors.dart';

/// Detects phone shaking. If more than 75% of the samples taken in the past 0.5s are
/// accelerating, the device is a) shaking, or b) free falling 1.84m (h =
/// 1/2*g*t^2*3/4).
///
/// @author Bob Lee (bob@squareup.com)
/// @author Eric Burke (eric@squareup.com)
class ShakeDetector {
  static final sensitivityLight = 11;
  static final sensitivityMedium = 13;
  static final sensitivityHard = 15;

  static final _defaultAccelerationThreshold = sensitivityMedium;

  /// When the magnitude of total acceleration exceeds this
  /// value, the phone is accelerating.
  var _accelerationThreshold = _defaultAccelerationThreshold;

  final _queue = _SampleQueue();

  /// Called on the main thread when the device is shaken. */
  final Function listener;

  /// StreamSubscription for Accelerometer events
  StreamSubscription streamSubscription;

  /// Starts listening for shakes on devices with appropriate hardware.
  ShakeDetector(this.listener) {
    streamSubscription = accelerometerEvents.listen(_onSensorChanged);
  }

  /// Stops listening.  Safe to call when already stopped.  Ignored on devices
  /// without appropriate hardware.
  void stop() {
    streamSubscription.cancel();
  }

  void _onSensorChanged(AccelerometerEvent event) {
    final accelerating = _isAccelerating(event);
    final timestamp = DateTime.now().microsecondsSinceEpoch * 1000;
    _queue._add(timestamp, accelerating);
    if (_queue._isShaking()) {
      _queue._clear();
      listener.call();
    }
  }

  /// Returns true if the device is currently accelerating. */
  bool _isAccelerating(AccelerometerEvent event) {
    final ax = event.x;
    final ay = event.y;
    final az = event.z;

    // Instead of comparing magnitude to ACCELERATION_THRESHOLD,
    // compare their squares. This is equivalent and doesn't need the
    // actual magnitude, which would be computed using (expensive) Math.sqrt().
    final magnitudeSquared = ax * ax + ay * ay + az * az;
    return magnitudeSquared > _accelerationThreshold * _accelerationThreshold;
  }

  /// Sets the acceleration threshold sensitivity. */
  void setSensitivity(int accelerationThreshold) {
    _accelerationThreshold = accelerationThreshold;
  }
}

/// Queue of samples. Keeps a running average. */
class _SampleQueue {
  /// Window size in ns. Used to compute the average. */
  static final _maxWindowSize = 500000000; // 0.5s
  static final _minWindowSize = _maxWindowSize >> 1; // 0.25s

  /// Ensure the queue size never falls below this size, even if the device
  /// fails to deliver this many events during the time window. The LG Ally
  /// is one such device.
  static final _minQueueSize = 4;

  final pool = _SamplePool();

  _Sample _oldest;
  _Sample _newest;
  var _sampleCount = 0;
  var _acceleratingCount = 0;

  /// Adds a sample.
  ///
  /// @param timestamp    in nanoseconds of sample
  /// @param accelerating true if > {@link #accelerationThreshold}.
  void _add(int timestamp, bool accelerating) {
    // Purge samples that proceed window.
    _purge(timestamp - _maxWindowSize);

    // Add the sample to the queue.
    _Sample added = pool._acquire();
    added._timestamp = timestamp;
    added._accelerating = accelerating;
    added._next = null;
    if (_newest != null) {
      _newest._next = added;
    }
    _newest = added;
    if (_oldest == null) {
      _oldest = added;
    }

    // Update running average.
    _sampleCount++;
    if (accelerating) {
      _acceleratingCount++;
    }
  }

  /// Removes all samples from this queue. */
  void _clear() {
    while (_oldest != null) {
      _Sample removed = _oldest;
      _oldest = removed._next;
      pool._release(removed);
    }
    _newest = null;
    _sampleCount = 0;
    _acceleratingCount = 0;
  }

  /// Purges samples with timestamps older than cutoff. */
  void _purge(int cutoff) {
    while (_sampleCount >= _minQueueSize &&
        _oldest != null &&
        cutoff - _oldest._timestamp > 0) {
      // Remove sample.
      _Sample removed = _oldest;
      if (removed._accelerating) {
        _acceleratingCount--;
      }
      _sampleCount--;

      _oldest = removed._next;
      if (_oldest == null) {
        _newest = null;
      }
      pool._release(removed);
    }
  }

  /// Returns true if we have enough samples and more than 3/4 of those samples
  /// are accelerating.
  bool _isShaking() {
    return _newest != null &&
        _oldest != null &&
        _newest._timestamp - _oldest._timestamp >= _minWindowSize &&
        _acceleratingCount >= (_sampleCount >> 1) + (_sampleCount >> 2);
  }
}

/// An accelerometer sample. */
class _Sample {
  /// Time sample was taken. */
  int _timestamp;

  /// If acceleration > {@link #accelerationThreshold}. */
  bool _accelerating;

  /// Next sample in the queue or pool. */
  _Sample _next;
}

/// Pools samples. Avoids garbage collection. */
class _SamplePool {
  _Sample _head;

  /// Acquires a sample from the pool. */
  _Sample _acquire() {
    _Sample acquired = _head;
    if (acquired == null) {
      acquired = _Sample();
    } else {
      // Remove instance from pool.
      _head = acquired._next;
    }
    return acquired;
  }

  /// Returns a sample to the pool. */
  void _release(_Sample sample) {
    sample._next = _head;
    _head = sample;
  }
}
