import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'mjpeg_stream.dart';

/// Where the camera service publishes its MJPEG stream. Override at build
/// time for a board on another address:
///
///     flutter build linux --release --dart-define=ESCA_CAMERA_URL=http://192.168.0.100:8080/stream
const String kCameraStreamUrl = String.fromEnvironment(
  'ESCA_CAMERA_URL',
  defaultValue: 'http://127.0.0.1:8080/stream',
);

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, this.url = kCameraStreamUrl});

  final String url;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

enum _Status { connecting, streaming, failed }

class _CameraScreenState extends State<CameraScreen> {
  MjpegStream? _stream;
  StreamSubscription<Uint8List>? _subscription;
  Timer? _retry;

  Uint8List? _frame;
  _Status _status = _Status.connecting;
  String _message = '';
  int _frameCount = 0;
  DateTime _since = DateTime.now();
  double _fps = 0;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _retry?.cancel();
    _subscription?.cancel();
    _stream?.close();
    super.dispose();
  }

  Future<void> _connect() async {
    _retry?.cancel();
    await _subscription?.cancel();
    await _stream?.close();

    setState(() {
      _status = _Status.connecting;
      _message = '';
    });

    final stream = MjpegStream(Uri.parse(widget.url));
    _stream = stream;

    _subscription = stream.frames.listen(
      _onFrame,
      onError: (Object error) => _fail(error.toString()),
    );

    try {
      await stream.start();
    } catch (error) {
      _fail(error.toString());
    }
  }

  void _onFrame(Uint8List jpeg) {
    if (!mounted) return;
    _frameCount++;
    final elapsed = DateTime.now().difference(_since).inMilliseconds;
    // Recompute the rate once a second: a per-frame average would never settle.
    if (elapsed >= 1000) {
      _fps = _frameCount * 1000 / elapsed;
      _frameCount = 0;
      _since = DateTime.now();
    }
    setState(() {
      _frame = jpeg;
      _status = _Status.streaming;
    });
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _status = _Status.failed;
      _message = message;
    });
    // The service may simply not be up yet; keep trying rather than making the
    // user hunt for a refresh button.
    _retry = Timer(const Duration(seconds: 3), _connect);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Camera'),
        actions: [
          if (_status == _Status.streaming)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text('${_fps.toStringAsFixed(1)} fps',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            ),
          IconButton(
            tooltip: 'Kết nối lại',
            onPressed: _connect,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    final frame = _frame;
    if (frame != null) {
      // gaplessPlayback keeps the previous frame on screen while the next one
      // decodes, instead of flashing black between frames.
      return InteractiveViewer(
        child: Image.memory(frame, gaplessPlayback: true, fit: BoxFit.contain),
      );
    }

    if (_status == _Status.failed) {
      return _Message(
        icon: Icons.videocam_off_outlined,
        title: 'Không kết nối được camera',
        detail: '${widget.url}\n$_message\n\nĐang thử lại...',
      );
    }

    return _Message(
      icon: Icons.videocam_outlined,
      title: 'Đang kết nối camera',
      detail: widget.url,
      busy: true,
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.detail,
    this.busy = false,
  });

  final IconData icon;
  final String title;
  final String detail;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(detail,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall),
          if (busy) ...[
            const SizedBox(height: 24),
            const SizedBox(
                width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ],
      ),
    );
  }
}
