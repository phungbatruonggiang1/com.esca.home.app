import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

/// Pulls whole JPEGs out of a byte stream.
///
/// It looks for the JPEG markers themselves — SOI (FF D8) to EOI (FF D9) —
/// rather than parsing multipart boundaries. Servers disagree about
/// boundaries, Content-Length and trailing CRLFs; every one of them sends
/// JPEGs that start and end the same way.
///
/// Kept separate from the socket so it can be tested without one.
class MjpegParser {
  final BytesBuilder _pending = BytesBuilder(copy: false);

  /// Feed bytes in, get whole frames out. Partial frames are held until the
  /// rest arrives.
  List<Uint8List> add(List<int> chunk) {
    _pending.add(chunk);
    final data = _pending.takeBytes();

    final frames = <Uint8List>[];
    var offset = 0;
    while (true) {
      final start = _indexOfMarker(data, 0xd8, offset);
      if (start < 0) {
        // Nothing usable; keep a single trailing byte in case it is half a
        // marker split across chunks.
        if (data.isNotEmpty) _pending.add(data.sublist(data.length - 1));
        return frames;
      }

      final end = _indexOfMarker(data, 0xd9, start + 2);
      if (end < 0) {
        _pending.add(Uint8List.sublistView(data, start));
        return frames;
      }

      frames.add(Uint8List.fromList(Uint8List.sublistView(data, start, end + 2)));
      offset = end + 2;
    }
  }

  /// Finds 0xFF followed by [marker], at or after [from].
  static int _indexOfMarker(Uint8List data, int marker, int from) {
    for (var i = from; i + 1 < data.length; i++) {
      if (data[i] == 0xff && data[i + 1] == marker) return i;
    }
    return -1;
  }
}

/// Reads an MJPEG stream (multipart/x-mixed-replace) and emits one JPEG per
/// frame.
///
/// Written on dart:io rather than a package on purpose: this app ships with no
/// plugins, and the camera preview must not be what finally drags a native
/// dependency in. Decoding the JPEGs is then dart:ui's job, which it does
/// without help.
class MjpegStream {
  MjpegStream(this.url);

  final Uri url;

  HttpClient? _client;
  StreamSubscription<List<int>>? _subscription;
  final _parser = MjpegParser();
  final _frames = StreamController<Uint8List>.broadcast();

  /// JPEG payloads, one per frame. A listener that arrives late gets the next
  /// frame, never a backlog.
  Stream<Uint8List> get frames => _frames.stream;

  bool _closed = false;

  Future<void> start() async {
    if (_closed) return;

    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    _client = client;

    final request = await client.getUrl(url);
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('stream returned ${response.statusCode}', uri: url);
    }

    _subscription = response.listen(
      (chunk) {
        for (final frame in _parser.add(chunk)) {
          if (!_frames.isClosed) _frames.add(frame);
        }
      },
      onError: (Object error, StackTrace stack) {
        if (!_frames.isClosed) _frames.addError(error, stack);
      },
      onDone: () {
        if (!_frames.isClosed) {
          _frames.addError(const SocketException('stream ended'));
        }
      },
      cancelOnError: true,
    );
  }

  Future<void> close() async {
    _closed = true;
    await _subscription?.cancel();
    _subscription = null;
    _client?.close(force: true);
    _client = null;
    await _frames.close();
  }
}
