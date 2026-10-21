import 'dart:async';

import 'package:esca_home/app_manager.dart';
import 'package:esca_home/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for esca-appmanagerd.
class FakeBackend implements AppManagerBackend {
  final launched = <String>[];
  final instances = <RunningInstance>[];
  final events = StreamController<LifeEvent>.broadcast();
  String? refuseWith;
  Set<String> up = {'vn.sparc.esca.AppManager1', 'vn.sparc.esca.Camera1'};

  @override
  Future<List<RunningInstance>> running() async => List.of(instances);

  @override
  Future<String> launch(String appId) async {
    if (refuseWith != null) throw AppManagerException(refuseWith!);
    launched.add(appId);
    instances.add(RunningInstance(appId, '$appId-1', 'running'));
    return '$appId-1';
  }

  @override
  Future<void> closeApp(String appId) async => instances.removeWhere((r) => r.appId == appId);

  @override
  Stream<LifeEvent> get lifeEvents => events.stream;

  @override
  Future<Map<String, bool>> present(Iterable<String> names) async =>
      {for (final name in names) name: up.contains(name)};

  @override
  Future<void> dispose() async => events.close();
}

/// Runs [body] against Home on a 1920x1200 screen backed by a [FakeBackend].
/// The controller is disposed inside the test, because its poll timer must
/// be gone before the test binding checks for pending timers.
void homeTest(String description, Future<void> Function(WidgetTester, FakeBackend) body) {
  testWidgets(description, (tester) async {
    tester.view.physicalSize = const Size(1920, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final backend = FakeBackend();
    final controller = AppManagerController(backend);
    await tester.pumpWidget(EscaHomeApp(controller: controller));
    await tester.pump();

    await body(tester, backend);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}

void main() {
  homeTest('shows the three applications and the service states', (tester, backend) async {
    expect(find.text('Camera AI'), findsOneWidget);
    expect(find.text('Sound Monitor'), findsOneWidget);
    expect(find.text('Voice Assistant'), findsOneWidget);
    // Four of the six services are not on the fake bus.
    expect(find.text('4 services stopped'), findsOneWidget);
  });

  homeTest('clicking an application asks the manager to launch it', (tester, backend) async {
    await tester.tap(find.text('Sound Monitor'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(backend.launched, ['vn.sparc.esca.monitor']);
    // 'Running' also labels every live service; 'Reopen' is the tile's own.
    expect(find.text('Reopen'), findsOneWidget);
  });

  homeTest('a refusal from the manager is shown, not swallowed', (tester, backend) async {
    backend.refuseWith = 'no such application';

    await tester.tap(find.text('Camera AI'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Camera AI: no such application'), findsOneWidget);
  });

  homeTest('a device tile toggles', (tester, backend) async {
    final tile =
        find.ancestor(of: find.text('Air conditioner'), matching: find.byType(InkWell)).first;
    final toggle = find.descendant(of: tile, matching: find.byType(Switch));
    expect(tester.widget<Switch>(toggle).value, isFalse);

    await tester.tap(toggle);
    await tester.pump();
    expect(tester.widget<Switch>(toggle).value, isTrue);
  });
}
