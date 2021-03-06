import 'dart:async';

import 'package:async/async.dart';

const _defaultNumRetries = 3;
const _defaultPeriod = const Duration(milliseconds: 600);

/// An object that expects a periodic signal from some remote resource.
///
/// If the remote resource fails to notify this monitor that it is available,
/// the monitor will announce that the resources is gone.
class SignalMonitor {
  final _stopMemo = new AsyncMemoizer();
  final _goneCompleter = new Completer<String>();
  final int _numRetries;
  final Duration _pingInterval;

  StreamSubscription _subscription;
  int _currentRetries = 0;
  Timer _timer;

  /// Creates a new [SignalMonitor].
  ///
  /// [numRetries] is the number of signals that can be missed before a resource
  /// is considered unavailable. [pingInterval] is the duration allowed
  /// between successive signals.
  SignalMonitor(
    Stream stream, {
    int numRetries: _defaultNumRetries,
    Duration pingInterval: _defaultPeriod,
  })
      : _numRetries = numRetries,
        _pingInterval = pingInterval {
    _restartTimer();
    _subscription = stream.listen((_) {
      _acknowledgeSignal();
    });
  }

  /// Whether the signal is still being received.
  bool get isAlive => !_goneCompleter.isCompleted;

  /// Completes when the signal is gone.
  Future get gone => _goneCompleter.future;

  /// Stops monitoring the signal
  Future stop() => _stopMemo.runOnce(() {
        _subscription.cancel();
        _timer.cancel();
        _goneCompleter.complete();
      });

  void _acknowledgeSignal() {
    _errorIfGone();
    _currentRetries = 0;
    _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = new Timer.periodic(_pingInterval, (_) {
      if (++_currentRetries > _numRetries) {
        stop();
      }
    });
  }

  void _errorIfGone() {
    if (!isAlive) {
      throw new StateError("The signal is dead");
    }
  }
}
