import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'folder_logic.dart';

class SyncLogic extends ChangeNotifier {
  String apiUrl = 'http://127.0.0.1:8389/rest';
  String apiKey = '';

  String localDeviceId = 'Not connected';
  bool isOnline = false;
  bool isFetching = false;
  bool isManualSyncing = false; // Tracks manual force sync

  Map<String, dynamic> pendingDevices = {};
  Map<String, dynamic> pendingFolders = {};

  // NEW: Store stats and connected peers
  List<dynamic> connectedDevices = [];
  Map<String, dynamic> folderStatus = {};
  Map<String, dynamic> connections = {};

  Timer? _pollingTimer;

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  SyncLogic() {
    _loadSettings();
    _startPolling();
  }

  // --- NEW: DECLINE PENDING REQUESTS ---
  Future<void> ignorePendingDevice(String deviceId) async {
    try {
      await http.delete(
        Uri.parse('$apiUrl/cluster/pending/devices/$deviceId'),
        headers: {'X-API-Key': apiKey},
      );
      fetchPendingRequests(); // Refresh the UI
    } catch (e) {
      print("Error ignoring device: $e");
    }
  }

  Future<void> ignorePendingFolder(String folderId) async {
    try {
      await http.delete(
        Uri.parse('$apiUrl/cluster/pending/folders/$folderId'),
        headers: {'X-API-Key': apiKey},
      );
      fetchPendingRequests(); // Refresh the UI
    } catch (e) {
      print("Error ignoring folder: $e");
    }
  }

  void updateSessionKey(String key) {
    apiKey = key;
    print("SyncLogic: Received Session Key: $key");
    _retryConnection();
    notifyListeners();
  }

  Future<void> _retryConnection() async {
    int attempts = 0;
    while (attempts < 10 && !isOnline) {
      await checkStatus();
      if (!isOnline) {
        attempts++;
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    if (isOnline) {
      fetchPendingRequests();
      fetchStats();
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (isOnline) {
        fetchPendingRequests();
        fetchStats(); // Update stats regularly
      } else {
        checkStatus();
      }
    });
  }

  Future<void> checkStatus() async {
    if (apiKey.isEmpty) return;

    isFetching = true;
    notifyListeners();

    try {
      final healthRes = await http
          .get(Uri.parse('http://127.0.0.1:8389/rest/noauth/health'))
          .timeout(const Duration(seconds: 2));

      final response = await http
          .get(
            Uri.parse('http://127.0.0.1:8389/rest/system/status'),
            headers: {'X-API-Key': apiKey},
          )
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        localDeviceId = data['myID'];
        isOnline = true;
        fetchStats(); // Trigger fetch immediately
      } else {
        isOnline = false;
      }
    } catch (e) {
      isOnline = false;
    }

    isFetching = false;
    notifyListeners();
  }

  // --- NEW: FETCH STATS & DEVICES ---
  Future<void> fetchStats() async {
    if (!isOnline || apiKey.isEmpty) return;
    try {
      final statRes = await http.get(
        Uri.parse('$apiUrl/db/status?folder=leran-workspace'),
        headers: {'X-API-Key': apiKey},
      );
      if (statRes.statusCode == 200) {
        folderStatus = jsonDecode(statRes.body);
      } else {
        folderStatus = {};
      }

      final connRes = await http.get(
        Uri.parse('$apiUrl/system/connections'),
        headers: {'X-API-Key': apiKey},
      );
      if (connRes.statusCode == 200) {
        connections = jsonDecode(connRes.body);
      }

      final configRes = await http.get(
        Uri.parse('$apiUrl/config'),
        headers: {'X-API-Key': apiKey},
      );
      if (configRes.statusCode == 200) {
        final config = jsonDecode(configRes.body);
        connectedDevices = (config['devices'] as List)
            .where((d) => d['deviceID'] != localDeviceId)
            .toList();
      }
      notifyListeners();
    } catch (e) {
      print("Error fetching stats: $e");
    }
  }

  // --- NEW: MANUAL SYNC TRIGGER ---
  Future<void> triggerManualSync(FolderLogic folderLogic) async {
    isManualSyncing = true;
    notifyListeners();

    try {
      // 1. Force Syncthing Daemon to scan local folder
      await http
          .post(
            Uri.parse('$apiUrl/db/scan?folder=leran-workspace'),
            headers: {'X-API-Key': apiKey},
          )
          .timeout(const Duration(seconds: 5));

      // 2. Force Flutter App to re-read files (Fixes Android reinstall glitch)
      await folderLogic.forceRescan();

      // 3. Update transfer UI stats
      await fetchStats();
    } catch (e) {
      print("Manual sync error: $e");
    }

    isManualSyncing = false;
    notifyListeners();
  }

  // --- NEW: RENAME DEVICE ---
  Future<void> renameDevice(String deviceId, String newName) async {
    try {
      final configRes = await http.get(
        Uri.parse('$apiUrl/config'),
        headers: {'X-API-Key': apiKey},
      );
      if (configRes.statusCode == 200) {
        final config = jsonDecode(configRes.body);
        List devices = config['devices'];
        int idx = devices.indexWhere((d) => d['deviceID'] == deviceId);
        if (idx != -1) {
          devices[idx]['name'] = newName;
          await http.put(
            Uri.parse('$apiUrl/config'),
            headers: {'X-API-Key': apiKey, 'Content-Type': 'application/json'},
            body: jsonEncode(config),
          );
          fetchStats();
        }
      }
    } catch (e) {
      print("Rename error: $e");
    }
  }

  // --- NEW: DISCONNECT / REMOVE DEVICE ---
  Future<void> disconnectDevice(String deviceId) async {
    try {
      final configRes = await http.get(
        Uri.parse('$apiUrl/config'),
        headers: {'X-API-Key': apiKey},
      );
      if (configRes.statusCode == 200) {
        final config = jsonDecode(configRes.body);

        List devices = config['devices'];
        devices.removeWhere((d) => d['deviceID'] == deviceId);
        config['devices'] = devices;

        List folders = config['folders'];
        for (var folder in folders) {
          List folderDevs = folder['devices'];
          folderDevs.removeWhere((d) => d['deviceID'] == deviceId);
          folder['devices'] = folderDevs;
        }
        config['folders'] = folders;

        await http.put(
          Uri.parse('$apiUrl/config'),
          headers: {'X-API-Key': apiKey, 'Content-Type': 'application/json'},
          body: jsonEncode(config),
        );
        fetchStats();
      }
    } catch (e) {
      print("Disconnect error: $e");
    }
  }

  Future<void> fetchPendingRequests() async {
    if (!isOnline || apiKey.isEmpty) return;
    try {
      final devRes = await http.get(
        Uri.parse('$apiUrl/cluster/pending/devices'),
        headers: {'X-API-Key': apiKey},
      );
      if (devRes.statusCode == 200) pendingDevices = jsonDecode(devRes.body);

      final folRes = await http.get(
        Uri.parse('$apiUrl/cluster/pending/folders'),
        headers: {'X-API-Key': apiKey},
      );
      if (folRes.statusCode == 200) pendingFolders = jsonDecode(folRes.body);

      notifyListeners();
    } catch (e) {}
  }

  Future<void> acceptPendingDevice(String deviceId) async {
    try {
      final configRes = await http.get(
        Uri.parse('$apiUrl/config'),
        headers: {'X-API-Key': apiKey},
      );
      if (configRes.statusCode == 200) {
        final config = jsonDecode(configRes.body);
        List devices = config['devices'];
        if (!devices.any((d) => d['deviceID'] == deviceId)) {
          devices.add({"deviceID": deviceId});
          config['devices'] = devices;

          await http.put(
            Uri.parse('$apiUrl/config'),
            headers: {'X-API-Key': apiKey, 'Content-Type': 'application/json'},
            body: jsonEncode(config),
          );

          await http.delete(
            Uri.parse('$apiUrl/cluster/pending/devices/$deviceId'),
            headers: {'X-API-Key': apiKey},
          );
          fetchPendingRequests();
          fetchStats(); // Update list immediately
        }
      }
    } catch (e) {}
  }

  Future<void> acceptPendingFolder(
    String folderId,
    String folderLabel,
    String remoteDeviceId,
    String localPath,
  ) async {
    try {
      final configRes = await http.get(
        Uri.parse('$apiUrl/config'),
        headers: {'X-API-Key': apiKey},
      );
      if (configRes.statusCode == 200) {
        final config = jsonDecode(configRes.body);
        List folders = config['folders'];

        if (!folders.any((f) => f['id'] == folderId)) {
          folders.add({
            "id": folderId,
            "label": folderLabel,
            "path": localPath.replaceAll('\\', '/'),
            "devices": [
              {"deviceID": localDeviceId},
              {"deviceID": remoteDeviceId},
            ],
          });
          config['folders'] = folders;

          await http.put(
            Uri.parse('$apiUrl/config'),
            headers: {'X-API-Key': apiKey, 'Content-Type': 'application/json'},
            body: jsonEncode(config),
          );

          await http.delete(
            Uri.parse('$apiUrl/cluster/pending/folders/$folderId'),
            headers: {'X-API-Key': apiKey},
          );
          fetchPendingRequests();
        }
      }
    } catch (e) {}
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedKey = prefs.getString('syncthing_api_key');
    if (savedKey != null && apiKey.isEmpty) {
      apiKey = savedKey;
      checkStatus();
    }
  }

  Future<void> saveApiKey(String newKey) async {
    apiKey = newKey;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('syncthing_api_key', apiKey);
    notifyListeners();
    checkStatus();
  }

  Future<String?> addDeviceAndShareFolder(
    String remoteDeviceId,
    String? folderPath,
    String syncType,
  ) async {
    if (!isOnline) return "Error: Not connected to local daemon.";
    if (folderPath == null || folderPath.isEmpty)
      return "Error: No folder selected in Leran.";

    remoteDeviceId = remoteDeviceId.trim();

    try {
      final configRes = await http.get(
        Uri.parse('$apiUrl/config'),
        headers: {'X-API-Key': apiKey},
      );
      if (configRes.statusCode != 200)
        return "Failed to read config: ${configRes.body}";

      final config = jsonDecode(configRes.body);

      List devices = config['devices'];
      if (!devices.any((d) => d['deviceID'] == remoteDeviceId)) {
        devices.add({"deviceID": remoteDeviceId});
      }

      List folders = config['folders'];
      String folderId = "leran-workspace";
      int folderIndex = folders.indexWhere((f) => f['id'] == folderId);
      String safePath = folderPath.replaceAll('\\', '/');

      if (folderIndex == -1) {
        folders.add({
          "id": folderId,
          "label": "Leran Notes",
          "path": safePath,
          "type": syncType,
          "devices": [
            {"deviceID": localDeviceId},
            {"deviceID": remoteDeviceId},
          ],
        });
      } else {
        List folderDevices = folders[folderIndex]['devices'];
        if (!folderDevices.any((d) => d['deviceID'] == remoteDeviceId)) {
          folderDevices.add({"deviceID": remoteDeviceId});
        }
        folders[folderIndex]['path'] = safePath;
        folders[folderIndex]['type'] = syncType;
      }

      config['devices'] = devices;
      config['folders'] = folders;

      final putRes = await http.put(
        Uri.parse('$apiUrl/config'),
        headers: {'X-API-Key': apiKey, 'Content-Type': 'application/json'},
        body: jsonEncode(config),
      );

      if (putRes.statusCode != 200)
        return "Syncthing Rejected Config: ${putRes.body}";

      fetchStats(); // Refresh devices list
      return null;
    } catch (e) {
      return "Network Exception: $e";
    }
  }
}
