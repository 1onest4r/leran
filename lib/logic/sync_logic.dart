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
  bool isManualSyncing = false;

  Map<String, dynamic> pendingDevices = {};
  Map<String, dynamic> pendingFolders = {};

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

  void updateSessionKey(String key) {
    apiKey = key;
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
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (isOnline) {
        fetchPendingRequests();
        fetchStats();
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
      final response = await http
          .get(
            Uri.parse('$apiUrl/system/status'),
            headers: {'X-API-Key': apiKey},
          )
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        localDeviceId = data['myID'];
        isOnline = true;
        fetchStats();
      } else {
        isOnline = false;
      }
    } catch (e) {
      isOnline = false;
    }

    isFetching = false;
    notifyListeners();
  }

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

  Future<void> triggerManualSync(FolderLogic folderLogic) async {
    isManualSyncing = true;
    notifyListeners();
    try {
      await http
          .post(
            Uri.parse('$apiUrl/db/scan?folder=leran-workspace'),
            headers: {'X-API-Key': apiKey},
          )
          .timeout(const Duration(seconds: 5));
      await folderLogic.forceRescan();
      await fetchStats();
    } catch (e) {}
    isManualSyncing = false;
    notifyListeners();
  }

  // --- INTERNAL HELPERS FOR SYNCTHING JSON OBJECTS ---
  Map<String, dynamic> _createDevice(String id, {String? ipHint}) {
    List<String> addresses = ["dynamic"];
    // The Duct Tape: If Android Multicast fails, directly aim at the IP address
    if (ipHint != null && ipHint.trim().isNotEmpty) {
      addresses.insert(0, "tcp://${ipHint.trim()}:22000");
    }
    return {"deviceID": id, "addresses": addresses};
  }

  Map<String, dynamic> _createFolder(
    String id,
    String label,
    String path,
    String type,
    List<String> deviceIds,
  ) {
    return {
      "id": id,
      "label": label,
      "path": path,
      "type": type,
      "devices": deviceIds.map((d) => {"deviceID": d}).toList(),
      "rescanIntervalS": 3600,
      "fsWatcherEnabled": true,
      "fsWatcherDelayS": 10,
      "ignorePerms": true, // CRITICAL: Fixes Windows <-> Android Sync Crashing
    };
  }

  Future<String?> addDeviceAndShareFolder(
    String remoteDeviceId,
    String? folderPath,
    String syncType, {
    String? ipHint,
  }) async {
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
      List devices = config['devices'] ?? [];

      // Update or add Device
      int deviceIdx = devices.indexWhere(
        (d) => d['deviceID'] == remoteDeviceId,
      );
      if (deviceIdx == -1) {
        devices.add(_createDevice(remoteDeviceId, ipHint: ipHint));
      } else if (ipHint != null && ipHint.trim().isNotEmpty) {
        List addresses = devices[deviceIdx]['addresses'] ?? ["dynamic"];
        String targetIp = "tcp://${ipHint.trim()}:22000";
        if (!addresses.contains(targetIp)) {
          addresses.insert(0, targetIp);
          devices[deviceIdx]['addresses'] = addresses;
        }
      }

      // Update or add Folder
      List folders = config['folders'] ?? [];
      String folderId = "leran-workspace";
      int folderIdx = folders.indexWhere((f) => f['id'] == folderId);
      String safePath = folderPath.replaceAll('\\', '/');

      if (folderIdx == -1) {
        folders.add(
          _createFolder(folderId, "Leran Notes", safePath, syncType, [
            localDeviceId,
            remoteDeviceId,
          ]),
        );
      } else {
        List folderDevices = folders[folderIdx]['devices'];
        if (!folderDevices.any((d) => d['deviceID'] == remoteDeviceId)) {
          folderDevices.add({"deviceID": remoteDeviceId});
        }
        folders[folderIdx]['path'] = safePath;
        folders[folderIdx]['type'] = syncType;
        folders[folderIdx]['ignorePerms'] = true;
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

      fetchStats();
      return null;
    } catch (e) {
      return "Network Exception: $e";
    }
  }

  // --- PENDING REQUESTS ---
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

  Future<void> ignorePendingDevice(String deviceId) async {
    await http.delete(
      Uri.parse('$apiUrl/cluster/pending/devices/$deviceId'),
      headers: {'X-API-Key': apiKey},
    );
    fetchPendingRequests();
  }

  Future<void> ignorePendingFolder(String folderId) async {
    await http.delete(
      Uri.parse('$apiUrl/cluster/pending/folders/$folderId'),
      headers: {'X-API-Key': apiKey},
    );
    fetchPendingRequests();
  }

  Future<String?> acceptPendingDevice(String deviceId) async {
    try {
      final configRes = await http.get(
        Uri.parse('$apiUrl/config'),
        headers: {'X-API-Key': apiKey},
      );
      if (configRes.statusCode == 200) {
        final config = jsonDecode(configRes.body);
        List devices = config['devices'] ?? [];

        if (!devices.any((d) => d['deviceID'] == deviceId)) {
          devices.add(_createDevice(deviceId));
          config['devices'] = devices;

          final putRes = await http.put(
            Uri.parse('$apiUrl/config'),
            headers: {'X-API-Key': apiKey, 'Content-Type': 'application/json'},
            body: jsonEncode(config),
          );

          if (putRes.statusCode != 200)
            return "Syncthing Rejected Device: ${putRes.body}";
        }

        await ignorePendingDevice(deviceId); // Clears the request
        fetchStats();
        return null; // Success!
      }
      return "Failed to read local config.";
    } catch (e) {
      return "Error: $e";
    }
  }

  Future<String?> acceptPendingFolder(
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
      if (configRes.statusCode != 200) return "Failed to read config.";

      final config = jsonDecode(configRes.body);
      List folders = config['folders'] ?? [];

      int folderIdx = folders.indexWhere((f) => f['id'] == folderId);

      if (folderIdx == -1) {
        // Folder does not exist locally yet. Create it!
        folders.add(
          _createFolder(
            folderId,
            folderLabel,
            localPath.replaceAll('\\', '/'),
            "sendreceive",
            [localDeviceId, remoteDeviceId],
          ),
        );
      } else {
        // Folder ALREADY exists! Just map the new remote device to it.
        List folderDevices = folders[folderIdx]['devices'] ?? [];
        if (!folderDevices.any((d) => d['deviceID'] == remoteDeviceId)) {
          folderDevices.add({"deviceID": remoteDeviceId});
        }
        folders[folderIdx]['devices'] = folderDevices;
        folders[folderIdx]['path'] = localPath.replaceAll('\\', '/');
        folders[folderIdx]['ignorePerms'] =
            true; // Protect Android/Windows permissions
      }

      config['folders'] = folders;

      // SAFETY NET: Ensure the device is actually in our Devices list first!
      List devices = config['devices'] ?? [];
      if (!devices.any((d) => d['deviceID'] == remoteDeviceId)) {
        devices.add(_createDevice(remoteDeviceId));
        config['devices'] = devices;
      }

      final putRes = await http.put(
        Uri.parse('$apiUrl/config'),
        headers: {'X-API-Key': apiKey, 'Content-Type': 'application/json'},
        body: jsonEncode(config),
      );

      if (putRes.statusCode != 200)
        return "Syncthing Rejected Config: ${putRes.body}";

      await ignorePendingFolder(folderId); // Clears the request from the UI
      fetchStats();
      return null; // Success!
    } catch (e) {
      return "Error accepting folder: $e";
    }
  }

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
}
