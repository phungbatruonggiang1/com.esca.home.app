import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show FontFeature;

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';

/// One controllable thing in the house. State lives in memory only: the point
/// of the sample is the UI and the renderer, not a real home automation bus.
class Device {
  Device(this.name, this.room, this.icon, {this.isOn = false});

  final String name;
  final String room;
  final IconData icon;
  bool isOn;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Device> _devices = [
    Device('Đèn trần', 'Phòng khách', Icons.lightbulb_outline, isOn: true),
    Device('Điều hoà', 'Phòng khách', Icons.ac_unit),
    Device('Quạt hút', 'Nhà bếp', Icons.air),
    Device('Bình nóng lạnh', 'Phòng tắm', Icons.hot_tub),
    Device('Cửa cuốn', 'Nhà xe', Icons.garage_outlined),
    Device('Camera sân', 'Ngoài trời', Icons.videocam_outlined, isOn: true),
  ];

  late Timer _clock;
  DateTime _now = DateTime.now();

  /// Rebuild count, as a crude check that the board keeps rendering frames
  /// rather than drawing one and freezing.
  int _frames = 0;

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _now = DateTime.now();
        _frames++;
      });
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // One column on a small panel, two on anything desktop-sized.
            final columns = constraints.maxWidth > 900 ? 3 : 2;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(now: _now),
                  const SizedBox(height: 20),
                  const _SensorRow(),
                  const SizedBox(height: 20),
                  Text('Thiết bị',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: columns,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.9,
                    children: [
                      for (final device in _devices)
                        _DeviceCard(
                          device: device,
                          onChanged: (value) =>
                              setState(() => device.isOn = value),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _RuntimePanel(frames: _frames),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.now});

  final DateTime now;

  static String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final time = '${_two(now.hour)}:${_two(now.minute)}:${_two(now.second)}';
    final date = '${_two(now.day)}/${_two(now.month)}/${now.year}';

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(Icons.home_rounded,
              size: 28, color: Theme.of(context).colorScheme.primary),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ESCA Home',
                style: Theme.of(context).textTheme.headlineSmall),
            Text('Nhà của Giang',
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(time,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()])),
            Text(date, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ],
    );
  }
}

class _SensorRow extends StatelessWidget {
  const _SensorRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(
          child: _SensorCard(
              label: 'Nhiệt độ', value: '28.4', unit: '°C', icon: Icons.thermostat),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _SensorCard(
              label: 'Độ ẩm', value: '62', unit: '%', icon: Icons.water_drop_outlined),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _SensorCard(
              label: 'Điện tiêu thụ', value: '1.8', unit: 'kW', icon: Icons.bolt),
        ),
      ],
    );
  }
}

class _SensorCard extends StatelessWidget {
  const _SensorCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.icon,
  });

  final String label;
  final String value;
  final String unit;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(width: 4),
                Text(unit, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device, required this.onChanged});

  final Device device;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => onChanged(!device.isOn),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: device.isOn
                      ? scheme.primary.withValues(alpha: 0.2)
                      : Colors.white10,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  device.icon,
                  color: device.isOn ? scheme.primary : Colors.white38,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(device.name,
                        style: Theme.of(context).textTheme.titleSmall),
                    Text(device.room,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Switch(value: device.isOn, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

/// What is actually running this UI. On the board these lines are the proof
/// that the app runs natively on the Pi rather than on the development host.
class _RuntimePanel extends StatelessWidget {
  const _RuntimePanel({required this.frames});

  final int frames;

  @override
  Widget build(BuildContext context) {
    final view = View.of(context);
    final size = view.physicalSize;
    final rows = <String, String>{
      'Hệ điều hành': Platform.operatingSystem,
      'Kernel': Platform.operatingSystemVersion,
      'Tên máy': Platform.localHostname,
      'Dart runtime': Platform.version.split(' ').first,
      'Màn hình': '${size.width.toInt()}x${size.height.toInt()} '
          '@ ${view.devicePixelRatio.toStringAsFixed(1)}x',
      'Chế độ build': kReleaseMode ? 'release' : 'debug',
      'Số frame đã vẽ': '$frames',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.memory,
                    size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text('Thông tin runtime',
                    style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 12),
            for (final entry in rows.entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 150,
                      child: Text(entry.key,
                          style: Theme.of(context).textTheme.bodySmall),
                    ),
                    Expanded(
                      child: Text(entry.value,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Colors.white70,
                              )),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
