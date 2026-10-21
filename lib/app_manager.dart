// What ESCA Home knows about the other applications: which are running, how
// to start one, and whether the services they need are on the bus.
//
// Everything goes through esca-appmanagerd (vn.sparc.esca.AppManager1). Home
// never forks an application itself: the manager is what drops privileges,
// sets the Wayland environment and reports exits, and an application started
// behind its back would be invisible to it.

import 'dart:async';

import 'package:dbus/dbus.dart';
import 'package:flutter/foundation.dart';

/// One application Home can open. The id is the one its appinfo.json
/// declares under /usr/share/esca/applications.
class EscaApp {
  const EscaApp({
    required this.id,
    required this.title,
    required this.summary,
    required this.service,
  });

  final String id;
  final String title;
  final String summary;

  /// The bus name of the service the application is a screen for. Shown so a
  /// screen that opens onto nothing can be explained before it is opened.
  final String service;
}

/// The services Home reports on, in the order they are drawn.
const kEscaServices = <String, String>{
  'vn.sparc.esca.Camera1': 'Camera',
  'vn.sparc.esca.Vision1': 'Object detection',
  'vn.sparc.esca.Audio1': 'Audio',
  'vn.sparc.esca.Anomaly1': 'Anomaly detection',
  'vn.sparc.esca.Voice1': 'Voice',
  'vn.sparc.esca.AppManager1': 'Application manager',
};

class LifeEvent {
  const LifeEvent(this.appId, this.instance, this.status);

  final String appId;
  final String instance;

  /// launching, running, paused, closing or stopped.
  final String status;
}

class RunningInstance {
  const RunningInstance(this.appId, this.instance, this.status);

  final String appId;
  final String instance;
  final String status;
}

/// The bus, behind an interface so the screen can be exercised without one.
abstract interface class AppManagerBackend {
  Future<List<RunningInstance>> running();

  /// Returns the new instance id. Throws [AppManagerException] with the
  /// manager's own explanation when it refuses.
  Future<String> launch(String appId);

  Future<void> closeApp(String appId);

  Stream<LifeEvent> get lifeEvents;

  /// For each name, whether something currently owns it on the system bus.
  Future<Map<String, bool>> present(Iterable<String> names);

  Future<void> dispose();
}

class AppManagerException implements Exception {
  AppManagerException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DBusAppManagerBackend implements AppManagerBackend {
  DBusAppManagerBackend() : _client = DBusClient.system() {
    _object = DBusRemoteObject(
      _client,
      name: _name,
      path: DBusObjectPath('/vn/sparc/esca/AppManager1'),
    );
  }

  static const _name = 'vn.sparc.esca.AppManager1';
  static const _interface = 'vn.sparc.esca.AppManager1';

  // The system bus, explicitly: under Weston DBUS_SESSION_BUS_ADDRESS is set
  // and a default connection would look for the manager on the session bus.
  final DBusClient _client;
  late final DBusRemoteObject _object;

  @override
  Future<List<RunningInstance>> running() async {
    final reply = await _object.callMethod(_interface, 'Running', const [],
        replySignature: DBusSignature('a(ssist)'));
    return [
      for (final entry in reply.values.first.asArray())
        () {
          final fields = (entry as DBusStruct).children;
          return RunningInstance(fields[0].asString(), fields[1].asString(), fields[3].asString());
        }(),
    ];
  }

  @override
  Future<String> launch(String appId) async {
    final reply = await _object.callMethod(
      _interface,
      'Launch',
      // No launch parameters: an empty a{ss}.
      [DBusString(appId), DBusDict(DBusSignature('s'), DBusSignature('s'), const {})],
      replySignature: DBusSignature('s'),
    );
    final instance = reply.values.first.asString();
    if (instance.isEmpty) throw AppManagerException(await _lastError());
    return instance;
  }

  @override
  Future<void> closeApp(String appId) async {
    await _object.callMethod(
        _interface, 'CloseByAppId', [DBusString(appId), const DBusBoolean(false)],
        replySignature: DBusSignature('i'));
  }

  Future<String> _lastError() async {
    final reply = await _object.callMethod(_interface, 'GetErrorMessage', const [],
        replySignature: DBusSignature('s'));
    final message = reply.values.first.asString();
    return message.isEmpty ? 'The application could not be opened' : message;
  }

  @override
  Stream<LifeEvent> get lifeEvents => DBusRemoteObjectSignalStream(
        object: _object,
        interface: _interface,
        name: 'AppLifeStatusChanged',
        signature: DBusSignature('sss'),
      ).map((signal) => LifeEvent(
            // The manager sends (app id, instance, status).
            signal.values[0].asString(),
            signal.values[1].asString(),
            signal.values[2].asString(),
          ));

  @override
  Future<Map<String, bool>> present(Iterable<String> names) async {
    final owned = await _client.listNames();
    return {for (final name in names) name: owned.contains(name)};
  }

  @override
  Future<void> dispose() => _client.close();
}

enum AppState { stopped, opening, running }

/// Live state for the dashboard: per application whether it is open, plus the
/// presence of every service. Polls presence, listens for life events.
class AppManagerController extends ChangeNotifier {
  AppManagerController(this._backend, {Duration poll = const Duration(seconds: 5)}) {
    _events = _backend.lifeEvents.listen(_onEvent, onError: (_) {});
    _poll = Timer.periodic(poll, (_) => refresh());
    refresh();
  }

  final AppManagerBackend _backend;
  late final StreamSubscription<LifeEvent> _events;
  late final Timer _poll;

  final Map<String, AppState> _states = {};
  Map<String, bool> _services = {};
  bool _managerReachable = true;
  String _error = '';

  AppState stateOf(String appId) => _states[appId] ?? AppState.stopped;
  Map<String, bool> get services => _services;
  bool get managerReachable => _managerReachable;
  String get error => _error;

  void clearError() {
    if (_error.isEmpty) return;
    _error = '';
    notifyListeners();
  }

  Future<void> refresh() async {
    try {
      _services = await _backend.present(kEscaServices.keys);
      final running = await _backend.running();
      final open = {
        for (final r in running)
          if (r.status != 'stopped') r.appId,
      };
      for (final id in {..._states.keys, ...open}) {
        // An opening application keeps its spinner until the manager says
        // otherwise, rather than flickering back to "stopped" on a poll that
        // raced the fork.
        if (_states[id] == AppState.opening && !open.contains(id)) continue;
        _states[id] = open.contains(id) ? AppState.running : AppState.stopped;
      }
      _managerReachable = true;
    } catch (e) {
      _managerReachable = false;
      _services = {for (final name in kEscaServices.keys) name: false};
    }
    notifyListeners();
  }

  void _onEvent(LifeEvent event) {
    _states[event.appId] = switch (event.status) {
      'launching' => AppState.opening,
      'running' || 'paused' => AppState.running,
      _ => AppState.stopped,
    };
    notifyListeners();
  }

  /// Opens [app]. One that is already open is restarted, which is how it gets
  /// back in front: Weston offers a client no way to raise another's window.
  Future<void> open(EscaApp app) async {
    if (stateOf(app.id) == AppState.opening) return;
    _states[app.id] = AppState.opening;
    _error = '';
    notifyListeners();

    try {
      if ((await _backend.running()).any((r) => r.appId == app.id && r.status != 'stopped')) {
        await _backend.closeApp(app.id);
        await _waitUntilClosed(app.id);
      }
      await _backend.launch(app.id);
      _states[app.id] = AppState.running;
    } on AppManagerException catch (e) {
      _states[app.id] = AppState.stopped;
      _error = '${app.title}: ${e.message}';
    } catch (e) {
      _states[app.id] = AppState.stopped;
      _error = '${app.title}: cannot reach esca-appmanagerd';
    }
    notifyListeners();
  }

  Future<void> _waitUntilClosed(String appId) async {
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
      final running = await _backend.running();
      if (!running.any((r) => r.appId == appId && r.status != 'stopped')) return;
    }
  }

  @override
  void dispose() {
    _poll.cancel();
    _events.cancel();
    _backend.dispose();
    super.dispose();
  }
}
