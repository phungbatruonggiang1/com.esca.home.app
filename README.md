# com.esca.home.app

A smart-home dashboard in Flutter, written to answer one question: does a
Flutter UI run on a Raspberry Pi 4 booted from `esca-image`?

It shows a clock, three sensor cards, six device tiles you can toggle, and a
runtime panel listing the OS, kernel, hostname, Dart version, screen geometry
and a frame counter. That panel is the actual test: read it on the board and you
know the app is running there, in release mode, and still drawing frames.

No third-party packages, by design. A plugin would have to be cross-compiled
and packaged for the target as well, which is a different problem from the one
this sample is here to settle.

## Layout

    pubspec.yaml            no dependencies beyond the Flutter SDK
    lib/main.dart           app entry point and theme
    lib/home_screen.dart    the dashboard, its widgets, and the runtime panel

`linux/` is not in the repository. Generate it when you need a desktop build:

```bash
flutter create --platforms=linux --project-name esca_home .
```

That command adds the missing platform scaffolding and leaves `lib/` alone;
check `git status` afterwards anyway.

## Getting it onto the Pi 4

### Through Yocto, with meta-flutter (the real route)

`meta-flutter` has a `wrynose` branch, matching the oe-core that build-esca
uses, so it drops into `escalayers.py` like any other layer. It carries the
Flutter engine and two ways to run an app under the image's Weston session:

- `flutter-auto` (ivi-homescreen) — a Wayland client, which is what
  `esca-image` already has a compositor for.
- `flutter-pi` — renders straight to DRM/KMS, no compositor at all.

The app itself becomes a recipe that builds the bundle and installs it, with
`meta-flutter`'s own app recipes as the pattern to copy. Expect the engine build
to be heavy.

### Without rebuilding the image (quick check)

The development host here is aarch64, the same architecture as the Pi, so a
desktop build runs on the board without cross-compiling:

```bash
flutter build linux --release
scp -r build/linux/arm64/release/bundle root@192.168.1.43:/home/root/esca-home
```

Then on the board, inside the Weston session:

```bash
/home/root/esca-home/esca_home
```

Two things have to line up for this to work: the image needs GTK 3, which
`core-image-weston` has (it ships `gtk+3-demo`), and the host's glibc must not
be newer than the image's. It is the fast way to get a first answer, not the way
to ship.

## Status

Written, but never compiled or run: there is no Flutter SDK on this machine
(`flutter` and `dart` are both missing), so the code has not been through
`flutter analyze` or a build. Treat the first `flutter build` as part of the
review.
