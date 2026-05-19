import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../logic/sync_logic.dart';
import '../../logic/folder_logic.dart';

class SyncPage extends StatefulWidget {
  final SyncLogic syncLogic;
  final FolderLogic folderLogic;

  const SyncPage({
    super.key,
    required this.syncLogic,
    required this.folderLogic,
  });

  @override
  State<SyncPage> createState() => _SyncPageState();
}

class _SyncPageState extends State<SyncPage> {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _peerIdController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _apiKeyController.text = widget.syncLogic.apiKey;
    widget.syncLogic.checkStatus();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _peerIdController.dispose();
    super.dispose();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1073741824) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
    return '${(bytes / 1073741824).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'WORKSPACE SYNC',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListenableBuilder(
        listenable: widget.syncLogic,
        builder: (context, _) {
          return ListView(
            padding: const EdgeInsets.all(24.0),
            children: [
              _buildEngineStatusCard(),
              const SizedBox(height: 20),

              if (widget.syncLogic.isOnline) ...[
                _buildConnectedDevicesList(),
                const SizedBox(height: 16),
                _buildPendingRequestsCard(),
                const SizedBox(height: 16),
                _buildAddNewPeerCard(),
                const SizedBox(height: 16),
                _buildLocalStatusCard(),
              ] else ...[
                _buildTroubleshootingTip(),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildEngineStatusCard() {
    final isOnline = widget.syncLogic.isOnline;
    final primaryColor = Theme.of(context).colorScheme.primary;

    final folderStats = widget.syncLogic.folderStatus;
    int totalBytes = folderStats['globalBytes'] ?? 0;
    int totalFiles = folderStats['globalFiles'] ?? 0;

    return Card(
      elevation: 0,
      color: isOnline
          ? primaryColor.withOpacity(0.05)
          : Colors.red.withOpacity(0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isOnline ? primaryColor : Colors.red, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            isOnline
                ? Icon(Icons.cloud_sync, color: primaryColor, size: 36)
                : const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.red,
                    ),
                  ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isOnline ? "Sync Engine Online" : "Initializing Engine...",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isOnline ? primaryColor : Colors.red,
                    ),
                  ),
                  if (isOnline && folderStats.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        "Workspace: $totalFiles files (${_formatBytes(totalBytes)})",
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectedDevicesList() {
    final devices = widget.syncLogic.connectedDevices;
    if (devices.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4.0, bottom: 12.0),
          child: Text(
            "My Connected Devices",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        ...devices.map((device) {
          return _DeviceControlCard(
            device: device,
            syncLogic: widget.syncLogic,
            folderLogic: widget.folderLogic,
          );
        }),
      ],
    );
  }

  Widget _buildAddNewPeerCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.person_add_alt_1, color: Colors.blue),
                SizedBox(width: 12),
                Text(
                  "Pair a New Device",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              "Paste a remote Device ID here to establish a connection. Once paired, it will appear in your device list.",
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _peerIdController,
              decoration: InputDecoration(
                labelText: "Remote Device ID",
                hintText: "Paste ID here...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  if (_peerIdController.text.isNotEmpty) {
                    // Default to sendreceive just to establish the connection
                    String? errorMsg = await widget.syncLogic
                        .addDeviceAndShareFolder(
                          _peerIdController.text,
                          widget.folderLogic.folderPath ?? "/leran-temp",
                          'sendreceive',
                        );

                    if (errorMsg != null && !errorMsg.contains("Reject")) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(errorMsg),
                          backgroundColor: Colors.red,
                        ),
                      );
                    } else {
                      _peerIdController.clear();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Pairing request sent!"),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  }
                },
                child: const Text("Send Pairing Request"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalStatusCard() {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Your Device ID",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Share this ID with other devices so they can pair with you.",
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: SelectableText(
                widget.syncLogic.localDeviceId,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.copy, size: 18),
                label: const Text("Copy My ID"),
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(text: widget.syncLogic.localDeviceId),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Device ID copied!")),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingRequestsCard() {
    final pendingDevices = widget.syncLogic.pendingDevices;
    final pendingFolders = widget.syncLogic.pendingFolders;

    if (pendingDevices.isEmpty && pendingFolders.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 4,
      color: Theme.of(context).colorScheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.security,
                  color: Colors.green,
                ), // Changed icon to security
                SizedBox(width: 8),
                Text(
                  "Authentication Requests",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              "Unrecognized devices are blocked by default. Only accept devices you trust.",
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 12),

            // --- PENDING DEVICES ---
            ...pendingDevices.entries.map((entry) {
              String deviceId = entry.key;
              String deviceName = entry.value['name'] ?? 'Unknown Device';
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.computer, color: Colors.blue),
                  title: Text(
                    deviceName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text("Wants to pair with you"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () =>
                            widget.syncLogic.ignorePendingDevice(deviceId),
                        child: const Text(
                          "Decline",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () =>
                            widget.syncLogic.acceptPendingDevice(deviceId),
                        child: const Text("Accept"),
                      ),
                    ],
                  ),
                ),
              );
            }),

            // --- PENDING FOLDERS ---
            ...pendingFolders.entries.map((entry) {
              String folderId = entry.key;
              String folderLabel = entry.value['label'] ?? 'Unknown Folder';
              Map offeredBy = entry.value['offeredBy'] ?? {};
              String remoteDeviceId = offeredBy.keys.isNotEmpty
                  ? offeredBy.keys.first
                  : '';

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(
                    Icons.folder_shared,
                    color: Colors.orange,
                  ),
                  title: Text(
                    folderLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text("Workspace data incoming"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () =>
                            widget.syncLogic.ignorePendingFolder(folderId),
                        child: const Text(
                          "Decline",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          if (widget.folderLogic.folderPath == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Error: Open a folder in Leran to store these files!",
                                ),
                              ),
                            );
                            return;
                          }
                          widget.syncLogic.acceptPendingFolder(
                            folderId,
                            folderLabel,
                            remoteDeviceId,
                            widget.folderLogic.folderPath!,
                          );
                        },
                        child: const Text("Accept Data"),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTroubleshootingTip() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 10),
      child: Text(
        "Tip: If the engine doesn't start within 10 seconds, try restarting the app. Ensure no other instances of Syncthing are running on your device.",
        style: TextStyle(
          color: Colors.grey,
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

// --- NEW ISOLATED WIDGET FOR INDIVIDUAL DEVICE CONTROL ---
class _DeviceControlCard extends StatefulWidget {
  final Map device;
  final SyncLogic syncLogic;
  final FolderLogic folderLogic;

  const _DeviceControlCard({
    required this.device,
    required this.syncLogic,
    required this.folderLogic,
  });

  @override
  State<_DeviceControlCard> createState() => _DeviceControlCardState();
}

class _DeviceControlCardState extends State<_DeviceControlCard> {
  String _selectedSyncType = 'sendreceive';

  void _showRenameDialog(String deviceId, String currentName) {
    final ctrl = TextEditingController(
      text: currentName == "Unnamed Device" ? "" : currentName,
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Rename Device"),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: "Custom Name",
            hintText: "e.g., My Laptop",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              widget.syncLogic.renameDevice(deviceId, ctrl.text);
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  void _confirmDisconnect(String deviceId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Disconnect Device?"),
        content: const Text(
          "This will stop all syncing with this remote peer and unpair them.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              widget.syncLogic.disconnectDevice(deviceId);
              Navigator.pop(context);
            },
            child: const Text(
              "Disconnect",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String deviceId = widget.device['deviceID'];
    String deviceName = widget.device['name'] ?? '';
    if (deviceName.isEmpty) deviceName = "Unnamed Device";

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Icon, Name, Options
            Row(
              children: [
                const Icon(Icons.computer, color: Colors.blue, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        deviceName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        deviceId,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'rename')
                      _showRenameDialog(deviceId, deviceName);
                    if (value == 'disconnect') _confirmDisconnect(deviceId);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'rename',
                      child: Text("Rename Device"),
                    ),
                    const PopupMenuItem(
                      value: 'disconnect',
                      child: Text(
                        "Disconnect & Remove",
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),

            // Sync Mode Selector
            const Text(
              "Data Sharing Mode",
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedSyncType,
                  isExpanded: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  items: const [
                    DropdownMenuItem(
                      value: 'sendreceive',
                      child: Row(
                        children: [
                          Icon(Icons.sync, color: Colors.blue, size: 20),
                          SizedBox(width: 10),
                          Text("Two-Way Sync (Keep in Sync)"),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'sendonly',
                      child: Row(
                        children: [
                          Icon(Icons.upload, color: Colors.orange, size: 20),
                          SizedBox(width: 10),
                          Text("Send Only (Push to Device)"),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'receiveonly',
                      child: Row(
                        children: [
                          Icon(Icons.download, color: Colors.green, size: 20),
                          SizedBox(width: 10),
                          Text("Receive Only (Download Only)"),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedSyncType = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.folder_shared, size: 18),
                    label: const Text("Share Workspace"),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () async {
                      if (widget.folderLogic.folderPath == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Error: Open a folder in Leran first!",
                            ),
                          ),
                        );
                        return;
                      }
                      String? errorMsg = await widget.syncLogic
                          .addDeviceAndShareFolder(
                            deviceId,
                            widget.folderLogic.folderPath,
                            _selectedSyncType,
                          );
                      if (errorMsg != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(errorMsg),
                            backgroundColor: Colors.red,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Workspace shared successfully!"),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: widget.syncLogic.isManualSyncing
                        ? null
                        : () {
                            widget.syncLogic.triggerManualSync(
                              widget.folderLogic,
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  "Forcing sync with $deviceName...",
                                ),
                              ),
                            );
                          },
                    child: widget.syncLogic.isManualSyncing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text("Sync Now"),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
