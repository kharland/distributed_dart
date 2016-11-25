import 'dart:async';
import 'dart:io';

import 'package:distributed/interfaces/message.dart';
import 'package:distributed/interfaces/node.dart';
import 'package:distributed/interfaces/peer.dart';
import 'package:distributed/src/io/handshake.dart';
import 'package:distributed/src/networking/message_channel.dart';
import 'package:meta/meta.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// A node that runs on the Dart VM
class IONode extends Peer implements Node {
  final StreamController<Message> _onMessage =
      new StreamController<Message>.broadcast();
  final StreamController<Peer> _onConnect =
      new StreamController<Peer>.broadcast();
  final StreamController<Peer> _onDisconnect =
      new StreamController<Peer>.broadcast();
  final StreamController<Null> _onConnectFailed =
      new StreamController<Null>.broadcast();
  final StreamController<Null> _onZeroConnections =
      new StreamController<Null>();
  final Completer<Null> _onShutdown = new Completer<Null>();

  final Map<Peer, MessageChannel> _channels = <Peer, MessageChannel>{};
  final _ChannelServer _channelHost;

  @override
  @virtual
  final String cookie;

  int connectionCount = 0;
  StreamSubscription<WebSocketChannel> _channelSubscription;

  /// Creates a new [IONode].
  ///
  /// Parameters are named for convenience. All except [isHidden] are required.
  IONode(
      {String name,
      String hostname,
      int port,
      bool isHidden: false,
      this.cookie: ''})
      : _channelHost = new _ChannelServer(hostname, port),
        super(name, hostname, port: port, isHidden: isHidden) {
    _channelSubscription = _channelHost.onChannel.listen(_handshake);
  }

  /// Creates a new [IONode] from [peer].
  ///
  /// if [isHidden] is true, this [Node] will not connect to a [Peer]'s [Peer]s
  /// when establishing a new connection.
  factory IONode.fromPeer(Peer peer, {String cookie: ''}) => new IONode(
      name: peer.name,
      hostname: peer.hostname,
      port: peer.port,
      isHidden: peer.isHidden,
      cookie: cookie);

  @override
  Stream<Peer> get onConnect => _onConnect.stream;

  @override
  Stream<Peer> get onDisconnect => _onDisconnect.stream;

  /// Visible for testing
  Stream<Null> get onConnectFailed => _onConnectFailed.stream;

  @override
  Future<Null> get onShutdown => _onShutdown.future;

  @override
  Future<Null> get onStartup => _channelHost.onStartup;

  @override
  List<Peer> get peers => new List.unmodifiable(_channels.keys);

  @override
  void connect(Peer peer) {
    if (peers.contains(peer)) {
      throw new ArgumentError('Already connected to $peer');
    }
    _handshake(new IOWebSocketChannel.connect(peer.url), initiate: true);
  }

  @override
  void disconnect(Peer peer) {
    if (_channels.containsKey(peer)) {
      _channels.remove(peer).close();
    }
  }

  @override
  Future<Null> shutdown() async {
    await _channelSubscription.cancel();
    await _channelHost.close();
    _onMessage.close();
    _onConnect.close();
    if (peers.isNotEmpty) {
      peers.forEach(disconnect);
      await _onZeroConnections.stream.take(1).first;
    }
    _onZeroConnections.close();
    _onDisconnect.close();
    _onShutdown.complete();
  }

  @override
  void send(Peer peer, String action, String data) {
    if (!peers.contains(peer)) {
      throw new ArgumentError('Unknown peer: $peer');
    }
    _channels[peer].send(new Message(this, action, data));
  }

  @override
  Stream<Message> receive(String action) =>
      _onMessage.stream.where((Message message) => message.action == action);

  void _handshake(WebSocketChannel webSocketChannel, {bool initiate: false}) {
    var channel = new MessageChannel.from(webSocketChannel);

    new Handshake(this, channel, initiate: initiate)
        .finished
        .then((HandshakeResult result) {
      if (result.isError) {
        channel.close();
        _onConnectFailed.add(null);
      } else {
        _addChannel(result.remote, result.channel);
      }
    });
  }

  void _addChannel(Peer peer, MessageChannel channel) {
    var subscription = channel.onMessage.listen(_onMessage.add);

    _channels[peer] = channel;
    connectionCount++;

    channel.onClose.then((_) {
      subscription.cancel();
      _channels.remove(peer);
      connectionCount--;
      if (connectionCount <= 0) {
        _onZeroConnections.add(null);
      }
      _onDisconnect.add(peer);
    });

    _onConnect.add(peer);
  }
}

/// Listens for new WebSocket connections.
class _ChannelServer {
  final StreamController<WebSocketChannel> _onChannel =
      new StreamController<WebSocketChannel>();
  final Completer<Null> _onStartup = new Completer<Null>();
  StreamSubscription<HttpRequest> _serverSubscription;
  HttpServer _httpServer;

  _ChannelServer(String hostname, [int port = 9095]) {
    HttpServer.bind(hostname, port).then((HttpServer httpServer) {
      _httpServer = httpServer;
      _onStartup.complete();
      _serverSubscription = _httpServer.listen((HttpRequest request) async {
        if (WebSocketTransformer.isUpgradeRequest(request)) {
          _onChannel.add(new IOWebSocketChannel(
              await WebSocketTransformer.upgrade(request)));
        }
      });
    });
  }

  Future<Null> get onStartup => _onStartup.future;

  Stream<WebSocketChannel> get onChannel => _onChannel.stream;

  /// Stops listening for incoming connections.
  Future<Null> close() async {
    await _serverSubscription?.cancel();
    await _onChannel.close();
    await _httpServer.close();
  }
}
