import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:esca_home/mjpeg_stream.dart';

/// A stand-in JPEG: the markers are what the parser keys on, the middle is
/// only there to be preserved intact.
Uint8List jpeg(List<int> body) => Uint8List.fromList([0xff, 0xd8, ...body, 0xff, 0xd9]);

void main() {
  test('reads one frame out of one chunk', () {
    final parser = MjpegParser();
    final frames = parser.add(jpeg([1, 2, 3]));

    expect(frames, hasLength(1));
    expect(frames.single, equals(jpeg([1, 2, 3])));
  });

  test('joins a frame split across chunks', () {
    final parser = MjpegParser();
    final whole = jpeg([1, 2, 3, 4, 5]);

    expect(parser.add(whole.sublist(0, 3)), isEmpty);
    expect(parser.add(whole.sublist(3, 5)), isEmpty);
    final frames = parser.add(whole.sublist(5));

    expect(frames, hasLength(1));
    expect(frames.single, equals(whole));
  });

  test('reads two frames arriving in one chunk', () {
    final parser = MjpegParser();
    final frames = parser.add([...jpeg([1]), ...jpeg([2])]);

    expect(frames, hasLength(2));
    expect(frames[0], equals(jpeg([1])));
    expect(frames[1], equals(jpeg([2])));
  });

  test('skips the multipart headers between frames', () {
    final parser = MjpegParser();
    const headers = [
      13, 10, 45, 45, 102, 114, 97, 109, 101, 13, 10, // CRLF --frame CRLF
    ];
    final frames = parser.add([...jpeg([1]), ...headers, ...jpeg([2])]);

    expect(frames, hasLength(2));
    expect(frames[1], equals(jpeg([2])));
  });

  test('holds back an incomplete trailing frame', () {
    final parser = MjpegParser();
    final frames = parser.add([...jpeg([1]), 0xff, 0xd8, 9, 9]);

    expect(frames, hasLength(1));
    // The partial second frame completes on the next chunk rather than being
    // lost or emitted truncated.
    expect(parser.add([0xff, 0xd9]), hasLength(1));
  });
}
