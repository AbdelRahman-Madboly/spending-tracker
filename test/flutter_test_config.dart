import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:sqlite3/open.dart';

/// The dev machine this suite runs on has sqlite3's runtime shared library
/// (`libsqlite3.so.0`) but not the unversioned `libsqlite3.so` symlink that
/// `package:sqlite3` looks for by default on Linux — that symlink normally
/// comes from a `libsqlite3-dev`-style package. Real devices don't have this
/// problem: `sqlite3_flutter_libs` bundles its own binary with the app. This
/// only points the *test* runner at the library that is actually installed.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  if (Platform.isLinux) {
    open.overrideFor(
      OperatingSystem.linux,
      () => DynamicLibrary.open('libsqlite3.so.0'),
    );
  }
  await testMain();
}
