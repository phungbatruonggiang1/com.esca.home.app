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
      summary: 'Live camera view, with objects detected right on the board.',
      service: 'vn.sparc.esca.Camera1',
    ),
    Icons.videocam_rounded,
    EscaColors.info,
  ),
  AppEntry(
    EscaApp(
      id: 'vn.sparc.esca.monitor',
      title: 'Sound Monitor',
      summary: 'Listens to the machine and raises an alarm on abnormal sound.',
      service: 'vn.sparc.esca.Anomaly1',
    ),
    Icons.graphic_eq_rounded,
    EscaColors.violet,
  ),
  AppEntry(
    EscaApp(
      id: 'vn.sparc.esca.voiceapp',
      title: 'Voice Assistant',
      summary: 'Press to talk, read what was heard, and hear it read back.',
      service: 'vn.sparc.esca.Voice1',
    ),
    Icons.mic_rounded,
    EscaColors.accent,
  ),
  AppEntry(
    EscaApp(
      id: 'vn.sparc.esca.settings',
      title: 'Settings',
      summary: 'Wi-Fi, Ethernet and Bluetooth: connect the board and its devices.',
      service: 'vn.sparc.esca.Settings1',
    ),
    Icons.settings_rounded,
    EscaColors.warn,
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
    Device('Ceiling light', 'Living room', Icons.lightbulb_outline_rounded, isOn: true),
    Device('Air conditioner', 'Living room', Icons.ac_unit_rounded),
    Device('Exhaust fan', 'Kitchen', Icons.air_rounded),
    Device('Water heater', 'Bathroom', Icons.hot_tub_rounded),
    Device('Roller door', 'Garage', Icons.garage_outlined),
    Device('Yard light', 'Outdoors', Icons.light_outlined, isOn: true),
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
                      const SectionTitle('Applications'),
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
        const SectionTitle('Environment'),
        const Row(
          children: [
            Expanded(
              child: MetricTile(
                  label: 'Temperature', value: '28.4', unit: '°C', icon: Icons.thermostat_rounded),
            ),
            SizedBox(width: 16),
            Expanded(
              child: MetricTile(
                  label: 'Humidity', value: '62', unit: '%', icon: Icons.water_drop_outlined),
            ),
            SizedBox(width: 16),
            Expanded(
              child: MetricTile(
                  label: 'Power draw', value: '1.8', unit: 'kW', icon: Icons.bolt_rounded),
            ),
          ],
        ),
        const SizedBox(height: 28),
        SectionTitle(
          'Devices',
          trailing: Text(
            '${_devices.where((d) => d.isOn).length} of ${_devices.length} on',
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
        const SectionTitle('System services'),
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
        ? ('System unreachable', EscaColors.bad)
        : down == 0
            ? ('All systems running', EscaColors.good)
            : (down == 1 ? '1 service stopped' : '$down services stopped', EscaColors.warn);

    return Row(
      children: [
        const IconBadge(icon: Icons.home_rounded, size: 56),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ESCA Home', style: text.headlineMedium),
            const SizedBox(height: 2),
            Text('Giang\'s home · Raspberry Pi 4',
                style: text.bodyMedium?.copyWith(
                  color: EscaColors.textDim,
                )),
          ],
        ),
        const SizedBox(width: 24),
        // Static: a dot pulsing forever keeps the engine drawing at 60 Hz for as
        // long as the board is up, even with an application covering Home.
        StatusPill(label: label, color: color),
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
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
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
          '${_weekdays[_now.weekday - 1]}, ${_now.day} ${_months[_now.month - 1]} ${_now.year}',
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
                serviceUp ? 'Service ready' : 'Service not running',
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
          StatusPill(key: const ValueKey('running'), label: 'Running', color: color),
        AppState.opening => const StatusPill(
            key: ValueKey('opening'), label: 'Opening…', color: EscaColors.warn, live: true),
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
          state == AppState.running ? 'Reopen' : 'Open',
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
                    (controller.services[entry.key] ?? false) ? 'Running' : 'Stopped',
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
      ('Host', Platform.localHostname),
      ('Kernel', Platform.operatingSystemVersion.split(' ').take(3).join(' ')),
      ('Dart', Platform.version.split(' ').first),
      ('Display', '${size.width.toInt()}×${size.height.toInt()}'),
      ('Build', kReleaseMode ? 'release' : 'debug'),
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
              Text('Runtime', style: text.titleSmall),
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
