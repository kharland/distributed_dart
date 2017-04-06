import 'dart:async';

import 'package:distributed/distributed.dart';
import 'package:distributed/src/objects/interfaces.dart';
import 'package:distributed/src/port_daemon/http_daemon_client.dart';
import 'package:distributed/src/port_daemon/port_daemon.dart';
import 'package:distributed/src/port_daemon/ports.dart';

/// An object for communicating with a [PortDaemon].
abstract class PortDaemonClient {
  factory PortDaemonClient(String name, HostMachine daemonHost, Logger logger) =
      HttpDaemonClient;

  /// The [HostMachine] where this client's [PortDaemon] is running.
  HostMachine get daemonHost;

  /// Pings the daemon.
  ///
  /// Returns a future that completes with true iff a the daemon sends back a
  /// response.
  Future<bool> pingDaemon();

  /// Returns a mapping of node names to their registered ports.
  ///
  /// Returns an empty map if no nodes are registered or if an error occurred.
  Future<Map<String, int>> getNodes();

  /// Returns the url for connecting to the node named [nodeName].
  ///
  /// Returns the empty string if [nodeName] could not be found.
  Future<String> lookup(String nodeName);

  /// Returns a new port for this client's owner [Node].
  ///
  /// Returns a Future that completes with the new port if registration
  /// succeeded or [Ports.error] if it failed.
  Future<int> registerNode();

  /// Returns the url for the remote interaction server for the node named
  /// [nodeName].
  ///
  /// Returns the empty string if no server was found.
  Future<String> lookupServer(String nodeName);

  /// Returns a new port for this client's owner [Node] remote interaction
  /// server.
  ///
  /// Returns a Future that completes with the new port if registration
  /// succeeded or [Ports.error] if it failed.
  Future<int> registerServer();

  /// Instructs the daemon server to deregister this client.
  ///
  /// Returns a future that completes with true iff deregistration succeeded.
  Future<bool> deregister();
}
