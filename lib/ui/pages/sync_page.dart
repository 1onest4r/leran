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
  final TextEditingController _peerIdController = TextEditingController();
  final TextEditingController _ipHintController = TextEditingController();
  String _selectedSyncType = 'sendreceive';

  @override
  void initState() {
    super.initState();
    widget.syncLogic.checkStatus();
  }

  @override
  void dispose() {
    _peerIdController.dispose();
    _ipHintController.dispose();
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
          'SYNC WORKSPACE',
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
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Text(
                      "Waiting for Sync Engine to start...",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ),
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

    return Container(
      decoration: BoxDecoration(
        color: isOnline
            ? primaryColor.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOnline ? primaryColor : Colors.red,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          Icon(
            isOnline ? Icons.cloud_done : Icons.cloud_off,
            color: isOnline ? primaryColor : Colors.red,
            size: 36,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOnline ? "Sync Engine Online" : "Engine Offline",
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
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (isOnline)
            IconButton(
              icon: widget.syncLogic.isManualSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync),
              color: primaryColor,
              onPressed: widget.syncLogic.isManualSyncing
                  ? null
                  : () =>
                        widget.syncLogic.triggerManualSync(widget.folderLogic),
            ),
        ],
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
            "Paired Devices",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        ...devices.map((device) {
          String deviceId = device['deviceID'];
          String deviceName = device['name'] ?? 'Unnamed Device';
          if (deviceName.isEmpty) deviceName = 'Unnamed Device';

          // CRITICAL: Check live connection status!
          bool isConnected =
              widget.syncLogic.connections[deviceId]?['connected'] == true;

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: Theme.of(context).colorScheme.surface,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 8,
              ),
              leading: Stack(
                children: [
                  const CircleAvatar(
                    backgroundColor: Colors.white10,
                    child: Icon(Icons.computer, color: Colors.white),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isConnected ? Colors.green : Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).colorScheme.surface,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              title: Text(
                deviceName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                isConnected ? "Connected & Syncing" : "Disconnected",
                style: TextStyle(
                  color: isConnected ? Colors.green : Colors.redAccent,
                  fontSize: 12,
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () => _confirmDisconnect(deviceId),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAddNewPeerCard() {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.person_add_alt_1, color: Colors.blueAccent),
                SizedBox(width: 12),
                Text(
                  "Pair & Share Workspace",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _peerIdController,
              decoration: InputDecoration(
                labelText: "Remote Device ID (Required)",
                hintText: "Paste the 56-character ID...",
                prefixIcon: const Icon(Icons.qr_code),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _ipHintController,
              decoration: InputDecoration(
                labelText: "IP Address (Optional Duct-Tape)",
                hintText: "e.g., 192.168.1.5",
                prefixIcon: const Icon(Icons.wifi),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 8, left: 4),
              child: Text(
                "If Android devices refuse to connect locally, enter the target's IP address above to force a direct connection.",
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.link),
                label: const Text("Pair Device & Start Syncing"),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  if (_peerIdController.text.isEmpty) return;

                  if (widget.folderLogic.folderPath == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Error: Select a folder in the Folder tab first!",
                        ),
                      ),
                    );
                    return;
                  }

                  String? errorMsg = await widget.syncLogic
                      .addDeviceAndShareFolder(
                        _peerIdController.text,
                        widget.folderLogic.folderPath,
                        _selectedSyncType,
                        ipHint: _ipHintController.text,
                      );

                  if (errorMsg != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(errorMsg),
                        backgroundColor: Colors.red,
                      ),
                    );
                  } else {
                    _peerIdController.clear();
                    _ipHintController.clear();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Pairing config saved! Waiting for them to accept...",
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4.0, bottom: 8.0),
          child: Text(
            "Pending Requests",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
            ),
          ),
        ),

        ...pendingDevices.entries.map((entry) {
          final String deviceId = entry.key;

          return Card(
            color: Colors.orange.withOpacity(0.1),
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: Colors.orange),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              title: const Text("New Device Wants to Pair"),
              subtitle: Text(
                deviceId,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () =>
                        widget.syncLogic.ignorePendingDevice(deviceId),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () async {
                      final String? errorMsg = await widget.syncLogic
                          .acceptPendingDevice(deviceId);

                      if (errorMsg != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(errorMsg),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        }),

        ...pendingFolders.entries.map((entry) {
          final String folderId = entry.key;
          final String folderLabel = entry.value['label'] ?? 'Folder';

          final Map offeredBy = entry.value['offeredBy'] ?? {};
          final String remoteDeviceId = offeredBy.keys.isNotEmpty
              ? offeredBy.keys.first
              : '';

          return Card(
            color: Colors.blue.withOpacity(0.1),
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: Colors.blue),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              title: Text("Accept Workspace: $folderLabel"),
              subtitle: const Text("Incoming data request"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () =>
                        widget.syncLogic.ignorePendingFolder(folderId),
                  ),
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
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

                      final String? errorMsg = await widget.syncLogic
                          .acceptPendingFolder(
                            folderId,
                            folderLabel,
                            remoteDeviceId,
                            widget.folderLogic.folderPath!,
                          );

                      if (errorMsg != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(errorMsg),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildLocalStatusCard() {
    return Card(
      elevation: 0,
      color: Colors.white.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Your Local Device ID",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black26,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                widget.syncLogic.localDeviceId,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                textAlign: TextAlign.center,
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

  void _confirmDisconnect(String deviceId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Remove Device?"),
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
}
