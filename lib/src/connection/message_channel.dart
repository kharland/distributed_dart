import 'dart:async';

import 'package:async/async.dart';
import 'package:distributed/src/connection/socket.dart';
import 'package:distributed/src/monitoring/periodic_function.dart';
import 'package:distributed/src/monitoring/signal_monitor.dart';
import 'package:distributed.objects/public.dart';

import 'message_router.dart';

/// A channel for passing [Message]s.
///
/// Unlike most dart sinks, if the remote end of the connection is closed, this
/// connection will also close and its done Future will complete, regardless of
/// whether any data has been sent or received.
class MessageChannel {
  final MessageRouter _messageRouter;
  final _closeMemo = new AsyncMemoizer();
  final _doneCompleter = new Completer();

  PeriodicFunction _keepAliveSignal;
  SignalMonitor _connectionSignal;

  /// Creates a connection from [socket].
  ///
  /// [socket] will be closed when the connection is closed.
  factory MessageChannel.fromSocket(Socket socket) {
    var messageRouter = new MessageRouter(socket);
    return new MessageChannel(
        messageRouter, new SignalMonitor(messageRouter.systemStream));
  }

  MessageChannel(this._messageRouter, this._connectionSignal) {
    _keepAliveSignal = new PeriodicFunction(_pingRemote);
    _connectionSignal.gone.then((_) {
      close();
    });
  }

  /// A future that completes when this connection is closed.
  ///
  /// If the remote closes the connection, this is guaranteed to complete.
  Future get done => _doneCompleter.future;

  /// The [Stream] of messages sent to this connection.
  Stream<Message> get messages =>
      _messageRouter.userStream.map(Message.deserialize).asBroadcastStream();

  /// Sends [message] over this [MessageChannel].
  void send(Message message) {
    _messageRouter.sendToUser(Message.serialize(message));
  }

  /// Closes this [MessageChannel].
  void close() {
    _closeMemo.runOnce(() {
      _keepAliveSignal.stop();
      _connectionSignal.stop();
      _messageRouter.close();
      _doneCompleter.complete();
    });
  }

  void _pingRemote() {
    _messageRouter.sendToSystem('');
  }
}
