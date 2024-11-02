import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'package:fl_clash/common/common.dart';
import 'package:path/path.dart' as p;

class Windows {
  static final Windows _instance = Windows._internal();
  late final DynamicLibrary _shell32;

  factory Windows() => _instance;

  Windows._internal() {
    try {
      _shell32 = DynamicLibrary.open('shell32.dll');
    } catch (e) {
      throw Exception('Failed to load shell32.dll: $e');
    }
  }

  /// Executes a command with elevated privileges using ShellExecuteW.
  bool runAsAdmin(String command, String arguments) {
    final commandPtr = command.toNativeUtf16();
    final argumentsPtr = arguments.toNativeUtf16();
    final operationPtr = 'runas'.toNativeUtf16();

    try {
      final ShellExecuteW = _shell32.lookupFunction<
          IntPtr Function(Pointer<Utf16>, Pointer<Utf16>, Pointer<Utf16>,
              Pointer<Utf16>, Pointer<Utf16>, Int32),
          int Function(Pointer<Utf16>, Pointer<Utf16>, Pointer<Utf16>,
              Pointer<Utf16>, Pointer<Utf16>, int)>('ShellExecuteW');

      final result = ShellExecuteW(
        nullptr,
        operationPtr,
        commandPtr,
        argumentsPtr,
        nullptr,
        SW_SHOW,
      );

      return result > 32;
    } catch (e) {
      // Log the error if necessary
      return false;
    } finally {
      calloc.free(commandPtr);
      calloc.free(argumentsPtr);
      calloc.free(operationPtr);
    }
  }

  /// Registers a task in Task Scheduler to run the application at startup.
  Future<bool> registerTask(String appName) async {
    final executablePath = Platform.resolvedExecutable;
    final taskXml = '''
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.3" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Author>YourName</Author>
    <Description>Run $appName at user logon</Description>
  </RegistrationInfo>
  <Triggers>
    <LogonTrigger>
      <Enabled>true</Enabled>
    </LogonTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>true</StopIfGoingOnBatteries>
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <IdleSettings>
      <StopOnIdleEnd>false</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <AllowStartOnDemand>true</AllowStartOnDemand>
    <Enabled>true</Enabled>
    <Hidden>false</Hidden>
    <RunOnlyIfIdle>false</RunOnlyIfIdle>
    <WakeToRun>false</WakeToRun>
    <Priority>7</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>${_escapeXml(executablePath)}</Command>
    </Exec>
  </Actions>
</Task>''';

    try {
      final tempDir = Directory.systemTemp;
      final taskFile = File(p.join(tempDir.path, 'task.xml'));

      await taskFile.writeAsBytes(taskXml.encode('utf-16le'), flush: true);

      final result = await Process.run(
        'schtasks',
        [
          '/Create',
          '/TN',
          appName,
          '/XML',
          taskFile.path,
          '/F',
        ],
        runInShell: true,
      );

      if (result.exitCode != 0) {
        // Log the stderr if necessary
        return false;
      }

      return true;
    } catch (e) {
      // Log the error if necessary
      return false;
    }
  }

  String _escapeXml(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static const int SW_SHOW = 5;
}

final windows = Platform.isWindows ? Windows() : null;
