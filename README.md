# grassroots_dart_udx

A Dart implementation of UDX — reliable, multiplexed, and congestion-controlled streams over UDP.

[![Pub Version](https://img.shields.io/pub/v/grassroots_dart_udx)](https://pub.dev/packages/grassroots_dart_udx)
[![Dart SDK](https://img.shields.io/badge/Dart-%3E%3D3.0.0-blue)](https://dart.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Fork notice

This package is a fork of [`dart_udx`](https://pub.dev/packages/dart_udx) by Stephan M. February ([upstream repo](https://github.com/stephanfeb/dart-udx)). It is maintained at [github.com/danbachar/dart-udx](https://github.com/danbachar/dart-udx) for use by the Grassroots Networking transport layer while changes are in flight upstream.

All credit for the original UDX/QUIC implementation belongs to the upstream author. This fork preserves the upstream MIT license and copyright; modifications are additionally copyrighted by the fork maintainer (see `LICENSE`).

Differences from upstream (`dart_udx` 2.0.3) shipped in this fork:

- `UDXMultiplexer.onRawPacket` — non-UDX datagrams that arrive on the shared UDP socket are surfaced to a caller-provided callback instead of being dropped. This lets a single UDP port carry UDX traffic alongside an application-defined wire format (e.g. signaling/hole-punch datagrams).
- `UDXMultiplexer.send` returns `SocketException?` rather than `void`, so transport layers can observe send failures (unreachable host, EHOSTUNREACH, etc.) and surface them as explicit transport errors instead of letting them surface as uncaught async exceptions.

See [CHANGELOG.md](CHANGELOG.md) for the full history, including the upstream changelog merged in for context.

## Overview

UDX is a QUIC-inspired, UDP-based transport protocol that provides reliable, ordered delivery with advanced networking features. This Dart implementation offers the core building blocks for creating high-performance, connection-oriented communication over UDP.

## Key Features

- **Reliable & Ordered Delivery** - TCP-like reliability over UDP
- **CUBIC Congestion Control** - Optimal throughput with adaptive bandwidth utilization
- **Multi-layer Flow Control** - Both connection and stream-level flow control
- **Connection Migration** - Seamless network path changes for mobile applications
- **Path MTU Discovery** - Automatic optimization of packet sizes
- **Packet Pacing** - Smooth network utilization to prevent bursts
- **Stream Multiplexing** - Multiple concurrent streams per connection
- **Event-Driven Architecture** - Responsive, asynchronous I/O

### What's New in v2.0 (Enhanced QUIC Compliance)

- **Variable-Length Connection IDs** - Flexible CID sizes (0-20 bytes) for improved privacy
- **Version Negotiation** - Automatic protocol version negotiation
- **Graceful Connection Termination** - CONNECTION_CLOSE frames with error details
- **Unidirectional Streams** - Half-duplex streams for optimized data flow
- **STOP_SENDING Frame** - Receiver-initiated stream termination
- **Flow Control Signaling** - BLOCKED frames for better congestion visibility
- **Stream Priorities** - Priority-based stream scheduling
- **Anti-Amplification Protection** - Built-in DDoS mitigation per RFC 9000
- **Stateless Reset** - Connection recovery without state
- **ECN Support** - Infrastructure for Explicit Congestion Notification
- **Improved RTT Estimation** - RFC 9002 compliant ACK delay handling

See [CHANGELOG.md](CHANGELOG.md) for full details and migration guide.

## Installation

Add this package to your `pubspec.yaml`:

```yaml
dependencies:
  grassroots_dart_udx: ^2.1.0
```

Then run:

```bash
dart pub get
```

## Quick Start

### Basic Server

```dart
import 'dart:io';
import 'package:grassroots_dart_udx/grassroots_dart_udx.dart';

void main() async {
  final udx = UDX();
  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 8080);
  final multiplexer = UDXMultiplexer(socket);

  print('UDX server listening on port 8080');

  multiplexer.connections.listen((connection) {
    print('New connection from ${connection.remoteAddress}');

    connection.on('stream').listen((event) {
      final stream = event.data as UDXStream;

      stream.data.listen((data) {
        print('Received: ${String.fromCharCodes(data)}');
        stream.add(data); // Echo back
      });
    });
  });
}
```

### Basic Client

```dart
import 'dart:io';
import 'dart:typed_data';
import 'package:grassroots_dart_udx/grassroots_dart_udx.dart';

void main() async {
  final udx = UDX();
  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  final multiplexer = UDXMultiplexer(socket);

  final connection = multiplexer.createSocket(udx, '127.0.0.1', 8080);
  await connection.handshakeComplete;

  final stream = await UDXStream.createOutgoing(
    udx, connection, 1, 2, '127.0.0.1', 8080
  );

  // Send data
  final message = 'Hello, UDX!';
  await stream.add(Uint8List.fromList(message.codeUnits));

  // Receive echo
  stream.data.listen((data) {
    print('Received: ${String.fromCharCodes(data)}');
    stream.close();
    connection.close();
  });
}
```

### Sharing a UDP port with a non-UDX wire format

`UDXMultiplexer` ignores any datagram that does not parse as a UDX packet. Set `onRawPacket` to receive those datagrams yourself — useful when running a signaling protocol alongside UDX on a single port.

```dart
final multiplexer = UDXMultiplexer(socket)
  ..onRawPacket = (data, address, port) {
    // Handle non-UDX datagram (e.g. signaling)
  };
```

### Observing send failures

`UDXMultiplexer.send` returns a `SocketException?` so callers can decide how to react to undeliverable datagrams without relying on uncaught async error handlers.

```dart
final error = multiplexer.send(bytes, peerAddress, peerPort);
if (error != null) {
  // Surface as a transport error to the application layer
}
```

## Architecture

UDX follows a layered architecture for maximum flexibility:

- **`UDXMultiplexer`** - Manages I/O for multiple connections over a single UDP socket
- **`UDPSocket`** - Represents a single logical connection with handshake and flow control
- **`UDXStream`** - Provides reliable, ordered data streams with congestion control

This design enables advanced features like connection migration, where connections can seamlessly move between network interfaces.

## Advanced Features

- **Connection Migration** - Move connections between network interfaces without dropping
- **Flow Control** - Prevent overwhelming receivers at both connection and stream levels
- **Congestion Control** - CUBIC algorithm with slow start, congestion avoidance, and fast recovery
- **Error Recovery** - Automatic retransmission and duplicate detection
- **Performance Monitoring** - Built-in RTT, throughput, and congestion window metrics

## Documentation

For detailed API documentation, advanced usage examples, and best practices, see the [Developer Guide](DEVELOPER_GUIDE.md).

## Performance

UDX is designed for high-performance applications:

- Zero-copy packet processing where possible
- Efficient memory management with configurable buffers
- Packet pacing to maximize network utilization
- Adaptive MTU discovery for optimal packet sizes

## Contributing

This fork's primary purpose is to keep Grassroots Networking unblocked while upstream pull requests are in review. Bug fixes and improvements that make sense for general UDX users are welcome here; please also consider opening the same change against the [upstream repository](https://github.com/stephanfeb/dart-udx).

## License

MIT — see [LICENSE](LICENSE). Original copyright belongs to Stephan M. February (`dart_udx`); fork modifications are additionally copyrighted by Dan Bachar.

## Acknowledgments

- [`dart_udx`](https://github.com/stephanfeb/dart-udx) by Stephan M. February — the upstream package this fork is based on.
- The original [UDX protocol](https://github.com/holepunchto/udx) which inspired the Dart implementation, alongside concepts from QUIC and modern transport protocol design.
