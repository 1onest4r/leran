import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http; // <--- ADD THIS IMPORT

class DaemonManager {
  Process? _process;
  String? currentApiKey;

  // 1. Generate a secure random API key for this session
  String _generateRandomKey() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rnd = Random.secure();
    return List.generate(
      32,
      (index) => chars[rnd.nextInt(chars.length)],
    ).join();
  }

  String _getBinaryName() {
    if (Platform.isWindows) return 'syncthing-windows.exe';
    if (Platform.isLinux) return 'syncthing-linux';
    throw UnsupportedError('OS not supported for standard extraction');
  }

  Future<String?> _getAndroidNativeLibraryPath() async {
    try {
      final maps = await File('/proc/self/maps').readAsString();
      final regex = RegExp(r'\s+(/[^\s]+/lib/.*?/)libflutter\.so');
      final match = regex.firstMatch(maps);

      if (match != null) {
        final libDir = match.group(1)!;
        final targetPath = join(libDir, 'libsyncthing.so');
        if (await File(targetPath).exists()) return targetPath;
      }
    } catch (e) {
      print("Map read error: $e");
    }

    final supportDir = await getApplicationSupportDirectory();
    final libDir = Directory(join(supportDir.parent.path, 'lib'));
    if (libDir.existsSync()) {
      final files = libDir.listSync(recursive: true);
      for (var file in files) {
        if (file is File && file.path.endsWith('libsyncthing.so')) {
          return file.path;
        }
      }
    }
    return null;
  }

  Future<bool> _isDaemonAlreadyRunning(String apiKey) async {
    try {
      // CRITICAL FIX: Ping an AUTHENTICATED endpoint.
      // If it returns 200, it's alive AND our API key is correct!
      // If it throws 403, it's an old zombie process and needs to be killed.
      final res = await http
          .get(
            Uri.parse('http://127.0.0.1:8389/rest/system/status'),
            headers: {'X-API-Key': apiKey},
          )
          .timeout(const Duration(milliseconds: 800));
      return res.statusCode == 200;
    } catch (e) {
      return false; // Not running or unreachable
    }
  }

  Future startDaemon() async {
    // 1. Load or Generate the API Key permanently
    final prefs = await SharedPreferences.getInstance();

    // CRITICAL FIX: Match the exactly same key used in SyncLogic
    currentApiKey = prefs.getString('syncthing_api_key');

    if (currentApiKey == null || currentApiKey!.isEmpty) {
      currentApiKey = _generateRandomKey();
      await prefs.setString('syncthing_api_key', currentApiKey!);
      print("Generated new permanent API Key.");
    }

    // 2. CHECK IF IT IS ALREADY RUNNING AND AUTHENTICATED
    // Pass the API key to ensure it's not a leftover process from a previous build
    if (await _isDaemonAlreadyRunning(currentApiKey!)) {
      print(
        "SUCCESS: Syncthing is ALREADY running in the background. Re-attaching instantly!",
      );
      return; // Skip the rest of the boot sequence!
    }

    // 3. Kill old instances (Desktop only)
    // If we reach here on Windows, it either wasn't running, OR it was a zombie process rejecting our key.
    if (Platform.isWindows) {
      await Process.run('taskkill', ['/F', '/IM', _getBinaryName()]);
      await Future.delayed(const Duration(seconds: 1)); // Wait for port to free
    } else if (Platform.isLinux) {
      await Process.run('killall', [_getBinaryName()]);
      await Future.delayed(const Duration(seconds: 1));
    }

    if (_process != null) return;

    final supportDir = await getApplicationSupportDirectory();
    final configDirPath = join(supportDir.path, 'leran_sync_config');

    if (!Directory(configDirPath).existsSync()) {
      Directory(configDirPath).createSync(recursive: true);
    }

    String finalExecutablePath = '';

    // 4. OS SPECIFIC ROUTING
    if (Platform.isAndroid) {
      finalExecutablePath = await _getAndroidNativeLibraryPath() ?? '';
      if (finalExecutablePath.isEmpty) {
        print("CRITICAL ANDROID ERROR: libsyncthing.so not found!");
        return;
      }
    } else {
      String exeName = _getBinaryName();
      finalExecutablePath = join(supportDir.path, exeName);
      if (!await File(finalExecutablePath).exists()) {
        try {
          final data = await rootBundle.load('bin/$exeName');
          await File(
            finalExecutablePath,
          ).writeAsBytes(data.buffer.asUint8List());
          if (!Platform.isWindows) {
            await Process.run('chmod', ['+x', finalExecutablePath]);
          }
        } catch (e) {
          print("Extraction Error: $e");
          return;
        }
      }
    }

    // 5. START THE DAEMON
    try {
      _process = await Process.start(
        finalExecutablePath,
        [
          '--no-browser',
          '--no-restart',
          '--home=$configDirPath',
          '--gui-address=127.0.0.1:8389',
          '--gui-apikey=$currentApiKey',
        ],
        runInShell: Platform.isWindows,
        // --- CRITICAL FIX: ANDROID NEEDS THIS TO NOT CRASH ---
        environment: {'HOME': supportDir.path},
      );

      _process!.stdout
          .transform(utf8.decoder)
          .listen((data) => print("SYNC LOG: $data"));
      _process!.stderr
          .transform(utf8.decoder)
          .listen((data) => print("SYNC ENGINE ERROR: $data"));

      _process!.exitCode.then((code) {
        print("SYNCTHING DIED. Code: $code");
        _process = null;
      });

      print("Daemon started with PID: ${_process!.pid}");
    } catch (e) {
      print("CRITICAL: Failed to start Syncthing.");
      print("Error Detail: $e");
    }
  }

  void stopDaemon() {
    _process?.kill();
    _process = null;
  }
}
