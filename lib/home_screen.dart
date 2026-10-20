import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:flutter/material.dart';

import 'app_manager.dart';
import 'kit/theme.dart';
import 'kit/widgets.dart';

/// The applications Home opens, with the look each one carries itself.
class AppEntry {
  const AppEntry(this.app, this.icon, this.color);

  final EscaApp app;
  final IconData icon;
  final Color color;
}

const kApps = [
  AppEntry(
    EscaApp(
      id: 'vn.sparc.esca.camview',
      title: 'Camera AI',
      summary: 'Hình ảnh trực tiếp từ camera, vật thể được nhận diện ngay trên board.',
      service: 'vn.sparc.esca.Camera1',
    ),
    Icons.videocam_rounded,
    EscaColors.info,
  ),
  AppEntry(
    EscaApp(
      id: 'vn.sparc.esca.monitor',
      title: 'Giám sát âm thanh',
      summary: 'Lắng nghe máy móc và cảnh báo ngay khi có tiếng động bất thường.',
      service: 'vn.sparc.esca.Anomaly1',
    ),
    Icons.graphic_eq_rounded,
    EscaColors.violet,
  ),
  AppEntry(
    EscaApp(
      id: 'vn.sparc.esca.voiceapp',
      title: 'Trợ lý giọng nói',
      summary: 'Nhấn để nói, xem văn bản nhận dạng được và nghe đọc lại.',
      service: 'vn.sparc.esca.Voice1',
    ),
    Icons.mic_rounded,
    EscaColors.accent,
  ),
];

/// One controllable thing in the house. Kept in memory only: these tiles are
/// the smart-home side of the demo, not wired to real hardware yet.
class Device {
  Device(this.name, this.room, this.icon, {this.isOn = false});

  final String name;
  final String room;
  final IconData icon;
  bool isOn;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.controller});

  final AppManagerController controller;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Device> _devices = [
    Device('Đèn trần', 'Phòng khách', Icons.lightbulb_outline_rounded, isOn: true),
    Device('Điều hoà', 'Phòng khách', Icons.ac_unit_rounded),
    Device('Quạt hút', 'Nhà bếp', Icons.air_rounded),
    Device('Bình nóng lạnh', 'Phòng tắm', Icons.hot_tub_rounded),
    Device('Cửa cuốn', 'Nhà xe', Icons.garage_outlined),
    Device('Đèn sân', 'Ngoài trời', Icons.light_outlined, isOn: true),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: EscaBackground(
        child: SafeArea(
          child: ListenableBuilder(
            listenable: widget.controller,
            builder: (context, _) => LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 1200;
                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: wide ? 48 : 24,
                    vertical: wide ? 36 : 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Header(controller: widget.controller),
                      FaultBanner(message: widget.controller.error),
                      SizedBox(height: wide ? 36 : 24),
                      const SectionTitle('Ứng dụng'),
                      _AppGrid(controller: widget.controller, wide: wide),
                      SizedBox(height: wide ? 36 : 24),
                      if (wide)
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Expanded(flex: 3, child: _homeColumn()),
                              const SizedBox(width: 24),
                              Expanded(flex: 2, child: _systemColumn(fill: true)),
                            ],
                          ),
                        )
                      else ...[
                        _homeColumn(),
                        const SizedBox(height: 24),
                        _systemColumn(fill: false),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _homeColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Môi trường'),
        const Row(
          children: [
            Expanded(
              child: MetricTile(
                  label: 'Nhiệt độ', value: '28.4', unit: '°C', icon: Icons.thermostat_rounded),
            ),
            SizedBox(width: 16),
            Expanded(
              child: MetricTile(
                  label: 'Độ ẩm', value: '62', unit: '%', icon: Icons.water_drop_outlined),
            ),
            SizedBox(width: 16),
            Expanded(
              child: MetricTile(
                  label: 'Điện tiêu thụ', value: '1.8', unit: 'kW', icon: Icons.bolt_rounded),
            ),
          ],
        ),
        const SizedBox(height: 28),
        SectionTitle(
          'Thiết bị',
          trailing: Text(
            '${_devices.where((d) => d.isOn).length}/${_devices.length} đang bật',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        // Rows rather than a GridView: a lazy viewport cannot report the
        // intrinsic height the two columns are matched by, and six tiles
        // gain nothing from laziness.
        for (var row = 0; row < _devices.length; row += 3) ...[
          if (row > 0) const SizedBox(height: 16),
          Row(
            children: [
              for (var i = row; i < row + 3; i++) ...[
                if (i > row) const SizedBox(width: 16),
                Expanded(
                  child: i < _devices.length
                      ? _DeviceTile(
                          device: _devices[i],
                          onChanged: (value) => setState(() => _devices[i].isOn = value),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  /// [fill] stretches the services card to the height of the column beside
  /// it; only possible when there is a column beside it.
  Widget _systemColumn({required bool fill}) {
    final services = _ServicesCard(controller: widget.controller);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Dịch vụ hệ thống'),
        if (fill) Expanded(child: services) else services,
        const SizedBox(height: 16),
        const _RuntimeCard(),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.controller});

  final AppManagerController controller;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final down = controller.services.values.where((up) => !up).length;
    final (label, color) = !controller.managerReachable
        ? ('Mất kết nối hệ thống', EscaColors.bad)
        : down == 0
            ? ('Hệ thống hoạt động ổn định', EscaColors.good)
            : ('$down dịch vụ đang dừng', EscaColors.warn);

    return Row(
      children: [
        const IconBadge(icon: Icons.home_rounded, size: 56),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ESCA Home', style: text.headlineMedium),
            const SizedBox(height: 2),
            Text('Nhà của Giang · Raspberry Pi 4',
                style: text.bodyMedium?.copyWith(
                  color: EscaColors.textDim,
                )),
          ],
        ),
        const SizedBox(width: 24),
        StatusPill(label: label, color: color, live: down == 0 && controller.managerReachable),
        const Spacer(),
        const _Clock(),
      ],
    );
  }
}

/// Rebuilds itself once a second and nothing else: the rest of the dashboard
/// has no reason to be laid out again just because the seconds moved.
class _Clock extends StatefulWidget {
  const _Clock();

  @override
  State<_Clock> createState() => _ClockState();
}

class _ClockState extends State<_Clock> {
  late final Timer _timer;
  DateTime _now = DateTime.now();

  static const _weekdays = [
    'Thứ Hai',
    'Thứ Ba',
    'Thứ Tư',
    'Thứ Năm',
    'Thứ Sáu',
    'Thứ Bảy',
    'Chủ Nhật'
  ];

  @override
  void initState() {
    super.initState();
    _timer =
        Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _now = DateTime.now()));
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '${_two(_now.hour)}:${_two(_now.minute)}',
          style: text.displaySmall?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
            height: 1.0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${_weekdays[_now.weekday - 1]}, ${_two(_now.day)}/${_two(_now.month)}/${_now.year}',
          style: text.bodyMedium?.copyWith(color: EscaColors.textDim),
        ),
      ],
    );
  }
}

class _AppGrid extends StatelessWidget {
  const _AppGrid({required this.controller, required this.wide});

  final AppManagerController controller;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      for (final entry in kApps)
        _AppTile(
          entry: entry,
          state: controller.stateOf(entry.app.id),
          serviceUp: controller.services[entry.app.service] ?? false,
          onOpen: () => controller.open(entry.app),
        ),
    ];

    if (!wide) {
      return Column(
        children: [
          for (final tile in tiles)
            Padding(padding: const EdgeInsets.only(bottom: 16), child: tile),
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: 24),
            Expanded(child: tiles[i]),
          ],
        ],
      ),
    );
  }
}

class _AppTile extends StatelessWidget {
  const _AppTile({
    required this.entry,
    required this.state,
    required this.serviceUp,
    required this.onOpen,
  });

  final AppEntry entry;
  final AppState state;
  final bool serviceUp;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = entry.color;

    return EscaCard(
      onTap: state == AppState.opening ? null : onOpen,
      padding: const EdgeInsets.all(24),
      highlight: state == AppState.running ? color.withValues(alpha: 0.55) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(icon: entry.icon, color: color, size: 64),
              const Spacer(),
              _StateBadge(state: state, color: color),
            ],
          ),
          const SizedBox(height: 22),
          Text(entry.app.title, style: text.headlineSmall),
          const SizedBox(height: 8),
          Text(
            entry.app.summary,
            style: text.bodyMedium?.copyWith(color: EscaColors.textDim, height: 1.45),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Icon(
                serviceUp ? Icons.check_circle_rounded : Icons.pause_circle_outline_rounded,
                size: 16,
                color: serviceUp ? EscaColors.good : EscaColors.warn,
              ),
              const SizedBox(width: 6),
              Text(
                serviceUp ? 'Dịch vụ sẵn sàng' : 'Dịch vụ chưa chạy',
                style: text.bodySmall,
              ),
              const Spacer(),
              _OpenLabel(state: state, color: color),
            ],
          ),
        ],
      ),
    );
  }
}

class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.state, required this.color});

  final AppState state;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: switch (state) {
        AppState.running =>
          StatusPill(key: const ValueKey('running'), label: 'Đang chạy', color: color, live: true),
        AppState.opening => const StatusPill(
            key: ValueKey('opening'), label: 'Đang mở…', color: EscaColors.warn, live: true),
        AppState.stopped => const SizedBox.shrink(key: ValueKey('stopped')),
      },
    );
  }
}

class _OpenLabel extends StatelessWidget {
  const _OpenLabel({required this.state, required this.color});

  final AppState state;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (state == AppState.opening) {
      return SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2.4, color: color),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          state == AppState.running ? 'Mở lại' : 'Mở ứng dụng',
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 6),
        Icon(Icons.arrow_forward_rounded, size: 18, color: color),
      ],
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device, required this.onChanged});

  final Device device;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final on = device.isOn;
    return EscaCard(
      onTap: () => onChanged(!on),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: on ? EscaColors.accent.withValues(alpha: 0.18) : EscaColors.surfaceHigh,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(device.icon, color: on ? EscaColors.accent : EscaColors.textFaint),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(device.name, style: text.titleSmall, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(device.room, style: text.bodySmall, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Switch(value: on, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _ServicesCard extends StatelessWidget {
  const _ServicesCard({required this.controller});

  final AppManagerController controller;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return EscaCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Column(
        children: [
          for (final (i, entry) in kEscaServices.entries.indexed) ...[
            if (i > 0) const Divider(height: 1, color: EscaColors.border),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  PulseDot(
                    color: (controller.services[entry.key] ?? false)
                        ? EscaColors.good
                        : EscaColors.textFaint,
                    pulsing: false,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(entry.value, style: text.bodyLarge)),
                  Text(
                    (controller.services[entry.key] ?? false) ? 'Hoạt động' : 'Đã dừng',
                    style: text.bodySmall?.copyWith(
                      color: (controller.services[entry.key] ?? false)
                          ? EscaColors.good
                          : EscaColors.textFaint,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// What is running this UI. On the board it is the quickest proof that the
/// dashboard is the release build, natively, and not something else.
class _RuntimeCard extends StatelessWidget {
  const _RuntimeCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final view = View.of(context);
    final size = view.physicalSize;
    final rows = <(String, String)>[
      ('Máy', Platform.localHostname),
      ('Kernel', Platform.operatingSystemVersion.split(' ').take(3).join(' ')),
      ('Dart', Platform.version.split(' ').first),
      ('Màn hình', '${size.width.toInt()}×${size.height.toInt()}'),
      ('Bản dựng', kReleaseMode ? 'release' : 'debug'),
    ];

    return EscaCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.memory_rounded, size: 18, color: EscaColors.textDim),
              const SizedBox(width: 8),
              Text('Thông tin runtime', style: text.titleSmall),
            ],
          ),
          const SizedBox(height: 12),
          for (final (key, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(width: 96, child: Text(key, style: text.bodySmall)),
                  Expanded(
                    child: Text(value, style: text.bodyMedium, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
