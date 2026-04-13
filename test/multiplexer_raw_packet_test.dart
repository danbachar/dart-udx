import 'dart:io';
import 'dart:typed_data';
import 'package:dart_udx/src/cid.dart';
import 'package:dart_udx/src/packet.dart';
import 'package:dart_udx/dart_udx.dart';
import 'package:test/test.dart';

void main() {
  group('UDXMultiplexer onRawPacket', () {
    late RawDatagramSocket rawSocket;
    late UDXMultiplexer multiplexer;

    setUp(() async {
      rawSocket = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
      multiplexer = UDXMultiplexer(rawSocket);
    });

    tearDown(() {
      multiplexer.close();
    });

    test('fires callback when datagram is shorter than minimum UDX packet size',
        () {
      final remoteAddress = InternetAddress.loopbackIPv4;
      const remotePort = 12345;
      final rawData = Uint8List.fromList([1, 2, 3, 4, 5]); // 5 bytes < 18

      Uint8List? receivedData;
      InternetAddress? receivedAddress;
      int? receivedPort;
      multiplexer.onRawPacket = (data, address, port) {
        receivedData = data;
        receivedAddress = address;
        receivedPort = port;
      };

      multiplexer.handleIncomingDatagramForTest(
          rawData, remoteAddress, remotePort);

      expect(receivedData, equals(rawData));
      expect(receivedAddress, equals(remoteAddress));
      expect(receivedPort, equals(remotePort));
    });

    test('fires callback when destination CID length is invalid', () {
      final remoteAddress = InternetAddress.loopbackIPv4;
      const remotePort = 12345;

      // 18-byte datagram passes the length check, but byte[4] (dcidLen) = 21,
      // which exceeds the 20-byte CID maximum.
      final invalidCidData = Uint8List(18);
      invalidCidData[4] = 21;

      Uint8List? receivedData;
      multiplexer.onRawPacket = (data, address, port) {
        receivedData = data;
      };

      multiplexer.handleIncomingDatagramForTest(
          invalidCidData, remoteAddress, remotePort);

      expect(receivedData, equals(invalidCidData));
    });

    test('fires callback when datagram is too short for declared CID', () {
      final remoteAddress = InternetAddress.loopbackIPv4;
      const remotePort = 12345;

      // 18 bytes but declares a 20-byte CID starting at offset 5 — needs 25 bytes.
      final truncatedCidData = Uint8List(18);
      truncatedCidData[4] = 20;

      Uint8List? receivedData;
      multiplexer.onRawPacket = (data, address, port) {
        receivedData = data;
      };

      multiplexer.handleIncomingDatagramForTest(
          truncatedCidData, remoteAddress, remotePort);

      expect(receivedData, equals(truncatedCidData));
    });

    test('does not fire callback for a valid UDX packet', () {
      final remoteAddress = InternetAddress.loopbackIPv4;
      const remotePort = 12345;

      final synPacket = UDXPacket(
        destinationCid: ConnectionId.random(),
        sourceCid: ConnectionId.random(),
        destinationStreamId: 1,
        sourceStreamId: 1,
        sequence: 0,
        frames: [StreamFrame(data: Uint8List(0), isSyn: true)],
      );
      final synBytes = synPacket.toBytes();

      var callbackFired = false;
      multiplexer.onRawPacket = (data, address, port) {
        callbackFired = true;
      };

      multiplexer.handleIncomingDatagramForTest(
          synBytes, remoteAddress, remotePort);

      expect(callbackFired, isFalse);
    });

    test('silently drops non-UDX datagrams when callback is null', () {
      final remoteAddress = InternetAddress.loopbackIPv4;
      const remotePort = 12345;
      final rawData = Uint8List.fromList([1, 2, 3, 4, 5]);

      // onRawPacket left as null (the default).
      expect(
        () => multiplexer.handleIncomingDatagramForTest(
            rawData, remoteAddress, remotePort),
        returnsNormally,
      );
    });
  });
}
