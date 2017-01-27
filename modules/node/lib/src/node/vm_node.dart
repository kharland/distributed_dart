import 'dart:async';

import 'package:distributed.net/secret.dart';
import 'package:distributed.node/node.dart';
import 'package:distributed.node/src/connection/connection_server.dart';
import 'package:distributed.node/src/exceptions.dart';
import 'package:distributed.node/src/message/message_channels.dart';
import 'package:distributed.node/src/node/cross_platform_node.dart';
import 'package:distributed.node/src/peer_identification_strategy.dart';
import 'package:distributed.port_daemon/daemon_client.dart';
import 'package:distributed.port_daemon/src/ports.dart';
import 'package:fixnum/fixnum.dart';

Future<Node> spawn(
  String name, {
  String address: 'localhost',
  Secret secret: Secret.acceptAny,
  bool isHidden: false,
}) async {
  var daemonClient = new DaemonClient(name, address: address, secret: secret);
  Int64 nodePort = await daemonClient.registerNode(name);

  if (nodePort == Ports.invalidPort) {
    throw new DaemonException('Unable to register node $name');
  }

  var delegate = new CrossPlatformNode(
    name,
    address: address,
    isHidden: isHidden,
  );
  var channelServer = await ConnectionServer.bind(
    address,
    nodePort.toInt(),
    new MessageChannelsProvider(),
    new NameExchange(name),
    secret: secret,
  );
  return new VmNode(delegate, channelServer, daemonClient);
}

/// A node that runs on the Dart VM
class VmNode extends DelegatingNode {
  static const defaultHostname = 'localhost';
  static const defaultPort = 9000;

  final DaemonClient _daemonClient;
  final ConnectionServer _server;

  VmNode(Node delegate, this._server, this._daemonClient) : super(delegate) {
    _server.onConnection.forEach((Connection connection) {
      delegate.addConnection(connection);
    });
    _daemonClient.startHeartbeat();
  }

  @override
  Future shutdown() async {
    await super.shutdown();
    await _server.close(force: true);
    await _daemonClient.deregisterNode(name);
    _daemonClient.stopHeartBeat();
  }
}