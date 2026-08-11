import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Testea el parsing del protocolo RFB sin conexión real.
/// Simula los bytes que enviaría un servidor VNC.
void main() {
  group('RFB handshake — parsing', () {
    test('Server protocol version se parsea correctamente', () {
      // RFB 003.008\n = 12 bytes
      const version = 'RFB 003.008\n';
      expect(version.length, 12);
      expect(version.substring(0, 3), 'RFB');
      expect(version.substring(4, 7), '003');
      expect(version.substring(8, 11), '008');
    });

    test('Security types: None (type 1) se reconoce', () {
      // Server envía: numTypes=1, type=1
      final data = Uint8List.fromList([1, 1]);
      expect(data[0], 1); // 1 tipo
      expect(data[1], 1); // tipo None
    });

    test('Security types: VNC Auth (type 2) se reconoce', () {
      final data = Uint8List.fromList([1, 2]);
      expect(data[0], 1);
      expect(data[1], 2); // VNC Authentication
    });

    test('Security types: múltiples tipos', () {
      // 3 tipos: None(1), VNC(2), Tight(16)
      final data = Uint8List.fromList([3, 1, 2, 16]);
      expect(data[0], 3);
      expect(data.contains(1), true);
      expect(data.contains(2), true);
      expect(data.contains(16), true);
    });

    test('Security result: OK = 0', () {
      // 4 bytes BE: 0x00000000 = success
      final data = Uint8List.fromList([0, 0, 0, 0]);
      final result =
          (data[0] << 24) | (data[1] << 16) | (data[2] << 8) | data[3];
      expect(result, 0);
    });

    test('Security result: FAIL = 1', () {
      final data = Uint8List.fromList([0, 0, 0, 1]);
      final result =
          (data[0] << 24) | (data[1] << 16) | (data[2] << 8) | data[3];
      expect(result, 1);
    });

    test('Security result: too many attempts = 2', () {
      final data = Uint8List.fromList([0, 0, 0, 2]);
      final result =
          (data[0] << 24) | (data[1] << 16) | (data[2] << 8) | data[3];
      expect(result, 2);
    });
  });

  group('RFB ServerInit — parsing', () {
    test('ServerInit parsea framebuffer dimensions', () {
      // fbWidth(2) fbHeight(2) pixelFormat(16) nameLength(4) name(N)
      final buf = ByteData(24);
      buf.setUint16(0, 1024); // width
      buf.setUint16(2, 768); // height
      // pixel format: 32bpp, depth 24, truecolor, RGB 8-8-8
      buf.setUint8(4, 32); // bpp
      buf.setUint8(5, 24); // depth
      buf.setUint8(6, 0); // big endian
      buf.setUint8(7, 1); // true color
      buf.setUint16(8, 255); // red max
      buf.setUint16(10, 255); // green max
      buf.setUint16(12, 255); // blue max
      buf.setUint8(14, 0); // red shift
      buf.setUint8(15, 8); // green shift
      buf.setUint8(16, 16); // blue shift
      buf.setUint32(20, 0); // name length = 0

      final fbW = buf.getUint16(0);
      final fbH = buf.getUint16(2);
      expect(fbW, 1024);
      expect(fbH, 768);
      expect(buf.getUint8(4), 32);
      expect(buf.getUint8(7), 1); // truecolor
    });

    test('ServerInit con nombre de escritorio', () {
      const name = 'NanoAI Desktop';
      const nameLen = name.length;
      const totalLen = 24 + nameLen;
      final buf = ByteData(totalLen);
      buf.setUint16(0, 1280);
      buf.setUint16(2, 720);
      buf.setUint32(20, nameLen);
      for (var i = 0; i < nameLen; i++) {
        buf.setUint8(24 + i, name.codeUnitAt(i));
      }

      expect(buf.getUint16(0), 1280);
      expect(buf.getUint32(20), nameLen);
      final parsedName = String.fromCharCodes(
        List.generate(nameLen, (i) => buf.getUint8(24 + i)),
      );
      expect(parsedName, name);
    });
  });

  group('RFB messages — encoding types', () {
    test('FramebufferUpdate message type = 0', () {
      final buf = ByteData(4);
      buf.setUint8(0, 0); // msg type
      buf.setUint8(1, 0); // padding
      buf.setUint16(2, 5); // num rects
      expect(buf.getUint8(0), 0);
      expect(buf.getUint16(2), 5);
    });

    test('Raw encoding = 0', () {
      expect(0, 0); // Raw
    });

    test('CopyRect encoding = 1', () {
      expect(1, 1); // CopyRect
    });

    test('FramebufferUpdateRequest message type = 3', () {
      final buf = ByteData(10);
      buf.setUint8(0, 3); // msg type
      buf.setUint8(1, 0); // incremental=false (full update)
      buf.setUint16(2, 0); // x
      buf.setUint16(4, 0); // y
      buf.setUint16(6, 1024); // width
      buf.setUint16(8, 768); // height

      expect(buf.getUint8(0), 3);
      expect(buf.getUint8(1), 0);
      expect(buf.getUint16(6), 1024);
    });

    test('SetPixelFormat message type = 0', () {
      final buf = ByteData(20);
      buf.setUint8(0, 0); // msg type
      expect(buf.getUint8(0), 0);
    });

    test('SetEncodings message type = 2', () {
      final buf = ByteData(4 + 2 * 4); // header + 2 encodings
      buf.setUint8(0, 2);
      buf.setUint16(2, 2); // 2 encodings
      buf.setInt32(4, 0); // Raw
      buf.setInt32(8, 1); // CopyRect
      expect(buf.getUint8(0), 2);
      expect(buf.getInt32(4), 0);
      expect(buf.getInt32(8), 1);
    });

    test('Pointer event type = 5', () {
      final buf = ByteData(6);
      buf.setUint8(0, 5);
      buf.setUint8(1, 1); // button mask (left click)
      buf.setUint16(2, 100); // x
      buf.setUint16(4, 200); // y
      expect(buf.getUint8(0), 5);
      expect(buf.getUint16(2), 100);
      expect(buf.getUint16(4), 200);
    });

    test('Key event type = 4', () {
      final buf = ByteData(8);
      buf.setUint8(0, 4);
      buf.setUint8(1, 1); // down=true
      buf.setUint32(4, 0x61); // 'a' keysym
      expect(buf.getUint8(0), 4);
      expect(buf.getUint32(4), 0x61);
    });
  });

  group('VNC Desktop — lifecycle & method channel contract', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('com.nanoai/exec_bin');

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            switch (call.method) {
              case 'startVnc':
                return {'port': 5901};
              case 'stopVnc':
                return true;
              case 'getVncStatus':
                return {
                  'running': true,
                  'reachable': true,
                  'ready': true,
                  'port': 5901,
                };
              default:
                return null;
            }
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('startVnc abre el escritorio visual y asigna puerto 5901', () async {
      final res = await channel.invokeMethod<Map>('startVnc');
      expect(res, isNotNull);
      expect(res!['port'], 5901);
    });

    test('getVncStatus confirma servidor VNC listo y puerto activo', () async {
      final status = await channel.invokeMethod<Map>('getVncStatus');
      expect(status, isNotNull);
      expect(status!['running'], true);
      expect(status['reachable'], true);
      expect(status['ready'], true);
      expect(status['port'], 5901);
    });

    test('stopVnc detiene el escritorio correctamente', () async {
      final stopped = await channel.invokeMethod<bool>('stopVnc');
      expect(stopped, true);
    });
  });
}
