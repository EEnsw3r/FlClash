import 'dart:async';
import 'dart:io';
import 'package:fl_clash/models/models.dart' hide Process;
import 'package:launch_at_startup/launch_at_startup.dart';

import 'constant.dart';
import 'system.dart';
import 'windows.dart';

class AutoLaunch {
  static final AutoLaunch _instance = AutoLaunch._internal();

  factory AutoLaunch() => _instance;

  AutoLaunch._internal() {
    if (system.isDesktop) {
      launchAtStartup.setup(
        appName: appName,
        appPath: Platform.resolvedExecutable,
      );
    }
  }

  Future<bool> get isEnabled async {
    if (!system.isDesktop) return false;
    return await launchAtStartup.isEnabled();
  }

  Future<bool> get windowsIsEnabled async {
    if (!Platform.isWindows) return false;
    try {
      final result = await Process.run(
        'schtasks',
        ['/Query', '/TN', appName, '/V', '/FO', 'LIST'],
        runInShell: true,
      );

      if (result.exitCode != 0) {
        // Task does not exist or another error occurred
        return false;
      }

      return result.stdout.toString().contains(appName);
    } catch (e) {
      // Log the error if necessary
      return false;
    }
  }

  Future<bool> enable() async {
    if (!system.isDesktop) return false;
    if (Platform.isWindows) {
      final disabled = await windowsDisable();
      if (!disabled) {
        // Handle disable failure if necessary
      }
      return await launchAtStartup.enable();
    } else {
      return await launchAtStartup.enable();
    }
  }

  Future<bool> windowsDisable() async {
    if (!Platform.isWindows) return false;
    try {
      final result = await Process.run(
        'schtasks',
        ['/Delete', '/TN', appName, '/F'],
        runInShell: true,
      );
      return result.exitCode == 0;
    } catch (e) {
      // Log the error if necessary
      return false;
    }
  }

  Future<bool> windowsEnable() async {
    if (!Platform.isWindows) return false;
    final win = Windows();
    try {
      final success = await win.registerTask(appName);
      if (!success) {
        // Fallback to launchAtStartup if Windows task registration fails
        return await enable();
      }
      return success;
    } catch (e) {
      // Log the error if necessary
      return false;
    }
  }

  Future<bool> disable() async {
    if (!system.isDesktop) return false;
    if (Platform.isWindows) {
      return await windowsDisable();
    } else {
      return await launchAtStartup.disable();
    }
  }

  Future<void> updateStatus(AutoLaunchState state) async {
    if (!system.isDesktop) return;

    final isAutoLaunch = state.isAutoLaunch;
    if (Platform.isWindows && state.isAdminAutoLaunch) {
      final currentStatus = await windowsIsEnabled;
      if (currentStatus == isAutoLaunch) return;

      if (isAutoLaunch) {
        final enabled = await windowsEnable();
        if (!enabled) {
          // Optionally handle failure
        }
      } else {
        await windowsDisable();
      }
      return;
    }

    final currentStatus = await isEnabled;
    if (currentStatus == isAutoLaunch) return;

    if (isAutoLaunch) {
      await enable();
    } else {
      await disable();
    }
  }
}

final autoLaunch = system.isDesktop ? AutoLaunch() : null;
