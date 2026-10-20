# ESCA Home

The dashboard the Raspberry Pi 4 boots into: it opens every other ESCA
application, shows which services are up, and carries the smart-home tiles.

## Opening an application

Each tile asks `esca-appmanagerd` (`vn.sparc.esca.AppManager1`) to launch the
application; Home never starts one itself. The manager is what drops
privileges, sets the Wayland environment and reports exits — an application
started behind its back would be invisible to it.

The manager's bus policy admits only root and the `appmanager` group, so the
`weston` user Home runs as must be in that group (`esca-image.bb` does it).

An application that is already open is restarted when its tile is pressed:
Weston gives one client no way to raise another's window, and a press that
did nothing would look broken. Each application returns here by exiting.

## What is live and what is not

Live: which applications are running (`Running`, `AppLifeStatusChanged`) and
which services own their names on the system bus.

Not yet: the environment readings and device tiles are the smart-home side
of the demo, held in memory only.

## Layout

    lib/app_manager.dart   esca-appmanagerd over D-Bus, and the dashboard's state
    lib/home_screen.dart   the dashboard
    lib/kit/               the shared ESCA look

`linux/` is not in the repository; generate it with
`flutter create --platforms=linux --project-name esca_home .` when a desktop
build is wanted.

## Building and testing on the development host

    flutter pub get
    flutter analyze
    flutter test

The tests drive the screen against a fake service, so they need neither the
board nor the bus. `pubspec.lock` is committed: the Yocto build resolves the
same package versions the tests ran against.

On the board the bundle is built by its recipe in `meta-sparc-esca`
(`esca-flutter-app.inc`), run by `ivi-homescreen` inside the Weston session,
and started by `esca-appmanagerd` through the launcher in `/usr/bin`.

`lib/kit/` is the shared ESCA look, copied identically into every
application. Change one copy, copy it to the others.
