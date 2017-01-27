import 'package:distributed.net/secret.dart';
import 'package:distributed.node/node.dart';
import 'package:distributed.node/src/configuration.dart';
import 'package:distributed.utils/logging.dart';

export 'package:distributed.node/node.dart';
export 'package:distributed.node/src/node/vm_node.dart';

void configureDistributed() {
  setNodeProvider(new _VmNodeProvider());
  configureLogging();
}

class _VmNodeProvider implements NodeProvider {
  @override
  Node create(
    String name, {
    String hostname,
    Secret secret,
    bool isHidden: false,
  }) =>
      throw new UnimplementedError();
}