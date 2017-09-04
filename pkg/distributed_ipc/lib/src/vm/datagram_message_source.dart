import 'package:distributed.ipc/ipc.dart';
import 'package:distributed.ipc/src/internal/event_source.dart';
import 'package:distributed.ipc/src/udp/data_builder.dart';
import 'package:distributed.ipc/src/udp/datagram.dart';

class DatagramMessageSource extends EventSource<Message> {
  final _currentBuffer = <List<int>>[];

  DatagramMessageSource(
    EventSource<Datagram> dgSource,
    DataBuilder dataBuilder,
  ) {
    dgSource.onEvent((Datagram datagram) {
      switch (datagram.type) {
        case DatagramType.END:
          emit(new Message(dataBuilder.assembleParts(_currentBuffer)));
          return;
        case DatagramType.DATA:
          _currentBuffer.add(datagram.data);
          return;
        default:
          throw new UnsupportedError(datagram.type.toString());
      }
    });
  }
}
