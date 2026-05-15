import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import '../services/pi_connection_service.dart';
import 'dashboard_screen.dart';

class ConnectionScreen extends StatefulWidget {
  const ConnectionScreen({super.key});

  @override
  State<ConnectionScreen> createState() => _ConnectionScreenState();
}

class _ConnectionScreenState extends State<ConnectionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _hostController = TextEditingController(text: '192.168.1.100');
  final _portController = TextEditingController(text: '8000');

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PiConnectionService>(
      builder: (context, svc, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F3),
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(svc),
                _buildStatusBanner(svc),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tab,
                    children: [
                      _WifiTab(
                        svc: svc,
                        hostController: _hostController,
                        portController: _portController,
                      ),
                      _BleTab(svc: svc),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(PiConnectionService svc) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF1D9E75),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.sensors, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ForceTrack',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A))),
              Text('Connect to Raspberry Pi',
                  style:
                      TextStyle(fontSize: 13, color: Color(0xFF888780))),
            ],
          ),
          const Spacer(),
          if (svc.isConnected)
            TextButton.icon(
              onPressed: svc.disconnect,
              icon: const Icon(Icons.link_off, size: 16),
              label: const Text('Disconnect'),
              style: TextButton.styleFrom(foregroundColor: Colors.red.shade400),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(PiConnectionService svc) {
    final (color, icon, text) = switch (svc.state) {
      PiConnectionState.connected => (
          const Color(0xFFE1F5EE),
          Icons.check_circle_outline,
          svc.statusMessage
        ),
      PiConnectionState.connecting => (
          const Color(0xFFE6F1FB),
          Icons.sync,
          svc.statusMessage
        ),
      PiConnectionState.scanning => (
          const Color(0xFFEEEDFE),
          Icons.radar,
          svc.statusMessage
        ),
      PiConnectionState.error => (
          const Color(0xFFFCEBEB),
          Icons.error_outline,
          svc.errorMessage
        ),
      _ => (const Color(0xFFF1EFE8), Icons.cable, 'Not connected'),
    };

    final textColor = switch (svc.state) {
      PiConnectionState.connected => const Color(0xFF085041),
      PiConnectionState.connecting => const Color(0xFF0C447C),
      PiConnectionState.scanning => const Color(0xFF3C3489),
      PiConnectionState.error => const Color(0xFFA32D2D),
      _ => const Color(0xFF5F5E5A),
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          if (svc.state == PiConnectionState.connecting ||
              svc.state == PiConnectionState.scanning)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: textColor,
              ),
            )
          else
            Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 13, color: textColor, fontWeight: FontWeight.w500)),
          ),
          if (svc.isConnected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF1D9E75),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                svc.mode == ConnectionMode.wifi ? 'WiFi' : 'Bluetooth',
                style:
                    const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFE8E6DF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: TabBar(
          controller: _tab,
          indicator: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFD3D1C7), width: 0.5),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: const Color(0xFF1A1A1A),
          unselectedLabelColor: const Color(0xFF888780),
          labelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          tabs: const [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.wifi, size: 16),
                  SizedBox(width: 6),
                  Text('WiFi'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bluetooth, size: 16),
                  SizedBox(width: 6),
                  Text('Bluetooth'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// WiFi Tab
// ─────────────────────────────────────────

class _WifiTab extends StatelessWidget {
  final PiConnectionService svc;
  final TextEditingController hostController;
  final TextEditingController portController;

  const _WifiTab({
    required this.svc,
    required this.hostController,
    required this.portController,
  });

  @override
  Widget build(BuildContext context) {
    final busy = svc.state == PiConnectionState.connecting;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          _SectionLabel(label: 'Raspberry Pi address'),

          const SizedBox(height: 10),

          _card(
            child: Column(
              children: [

                _FormField(
                  label: 'IP Address',
                  hint: '192.168.1.100',
                  controller: hostController,
                  keyboard: TextInputType.url,
                  onChanged: svc.setWifiHost,
                ),

                const Divider(
                  height: 1,
                  thickness: 0.5,
                ),

                _FormField(
                  label: 'Port',
                  hint: '8000',
                  controller: portController,
                  keyboard: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  onChanged: (v) {
                    svc.setWifiPort(
                      int.tryParse(v) ?? 8000,
                    );
                  },
                ),

              ],
            ),
          ),

          const SizedBox(height: 16),

          _SectionLabel(label: 'Quick presets'),

          const SizedBox(height: 10),

          Row(
            children: [

              _Preset(
                label: 'raspberrypi.local',
                onTap: () {
                  hostController.text = 'raspberrypi.local';
                  svc.setWifiHost('raspberrypi.local');
                },
              ),

              const SizedBox(width: 8),

              _Preset(
                label: '10.0.0.1',
                onTap: () {
                  hostController.text = '10.0.0.1';
                  svc.setWifiHost('10.0.0.1');
                },
              ),

              const SizedBox(width: 8),

              _Preset(
                label: '192.168.0.1',
                onTap: () {
                  hostController.text = '192.168.0.1';
                  svc.setWifiHost('192.168.0.1');
                },
              ),

            ],
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 48,

            child: ElevatedButton(

              onPressed: (busy || svc.isConnected)
                  ? null
                  : () async {

                      await svc.connectWifi();

                      if (context.mounted &&
                          svc.isConnected) {

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const DashboardScreen(),
                          ),
                        );

                      }
                    },

              style: ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFF1D9E75),

                foregroundColor: Colors.white,

                disabledBackgroundColor:
                    const Color(0xFFB4B2A9),

                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(12),
                ),

                elevation: 0,
              ),

              child: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      svc.isConnected
                          ? 'Connected'
                          : 'Connect via WiFi',

                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
          ),

        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Bluetooth Tab
// ─────────────────────────────────────────

class _BleTab extends StatelessWidget {
  final PiConnectionService svc;

  const _BleTab({required this.svc});

  @override
  Widget build(BuildContext context) {
    final scanning = svc.state == PiConnectionState.scanning;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              const _SectionLabel(label: 'Nearby devices'),
              const Spacer(),
              TextButton.icon(
                onPressed: scanning ? null : svc.startBleScan,
                icon: scanning
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child:
                            CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh, size: 16),
                label: Text(scanning ? 'Scanning…' : 'Scan'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF1D9E75),
                  textStyle: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: svc.scanResults.isEmpty
              ? _BleEmptyState(scanning: scanning, onScan: svc.startBleScan)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: svc.scanResults.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final result = svc.scanResults[i];
                    return _BleDeviceCard(
                      result: result,
                      onConnect: () => svc.connectBle(result.device),
                      isConnecting: svc.state == PiConnectionState.connecting,
                      isConnected: svc.isConnected &&
                          svc.mode == ConnectionMode.bluetooth,
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: _InfoBox(
            icon: Icons.bluetooth_searching,
            text:
                'Enable Bluetooth on your Pi and run the BLE GATT server. The device should appear as "ForceTrack-Pi" in the list above.',
          ),
        ),
      ],
    );
  }
}

class _BleEmptyState extends StatelessWidget {
  final bool scanning;
  final VoidCallback onScan;

  const _BleEmptyState({required this.scanning, required this.onScan});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            scanning ? Icons.radar : Icons.bluetooth_disabled,
            size: 56,
            color: const Color(0xFFD3D1C7),
          ),
          const SizedBox(height: 16),
          Text(
            scanning ? 'Scanning for devices…' : 'No devices found',
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF888780)),
          ),
          const SizedBox(height: 8),
          Text(
            scanning
                ? 'Make sure your Pi\'s BLE server is running'
                : 'Tap Scan to search for nearby Bluetooth devices',
            style: const TextStyle(fontSize: 13, color: Color(0xFFB4B2A9)),
            textAlign: TextAlign.center,
          ),
          if (!scanning) ...[
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: onScan,
              icon: const Icon(Icons.search, size: 16),
              label: const Text('Start scan'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF1D9E75),
                side: const BorderSide(color: Color(0xFF1D9E75)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BleDeviceCard extends StatelessWidget {
  final ScanResult result;
  final VoidCallback onConnect;
  final bool isConnecting;
  final bool isConnected;

  const _BleDeviceCard({
    required this.result,
    required this.onConnect,
    required this.isConnecting,
    required this.isConnected,
  });

  String get _rssiLabel {
    final rssi = result.rssi;
    if (rssi >= -50) return 'Excellent';
    if (rssi >= -65) return 'Good';
    if (rssi >= -75) return 'Fair';
    return 'Weak';
  }

  Color get _rssiColor {
    final rssi = result.rssi;
    if (rssi >= -50) return const Color(0xFF1D9E75);
    if (rssi >= -65) return const Color(0xFF639922);
    if (rssi >= -75) return const Color(0xFFBA7517);
    return const Color(0xFFE24B4A);
  }

  bool get _isPi =>
      result.device.platformName.toLowerCase().contains('forcetrack') ||
      result.device.platformName.toLowerCase().contains('raspberrypi') ||
      result.device.platformName.toLowerCase().contains('pi');

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isPi
              ? const Color(0xFF1D9E75).withOpacity(0.4)
              : const Color(0xFFD3D1C7),
          width: _isPi ? 1.5 : 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _isPi
                    ? const Color(0xFFE1F5EE)
                    : const Color(0xFFF1EFE8),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _isPi ? Icons.developer_board : Icons.bluetooth,
                color: _isPi
                    ? const Color(0xFF085041)
                    : const Color(0xFF5F5E5A),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        result.device.platformName.isEmpty
                            ? 'Unknown device'
                            : result.device.platformName,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1A1A1A)),
                      ),
                      if (_isPi) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE1F5EE),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text('Pi',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF085041),
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    result.device.remoteId.str,
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFFB4B2A9)),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${result.rssi} dBm',
                  style: TextStyle(
                      fontSize: 11,
                      color: _rssiColor,
                      fontWeight: FontWeight.w500),
                ),
                Text(_rssiLabel,
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFFB4B2A9))),
                const SizedBox(height: 6),
                SizedBox(
                  height: 30,
                  child: ElevatedButton(
                    onPressed: (isConnecting || isConnected) ? null : onConnect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1D9E75),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFB4B2A9),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                    child: isConnecting
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Connect'),
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

// ─────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) => Text(
        label.toUpperCase(),
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.06,
            color: Color(0xFF888780)),
      );
}

Widget _card({required Widget child}) => Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD3D1C7), width: 0.5),
      ),
      child: child,
    );

class _FormField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType keyboard;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String> onChanged;

  const _FormField({
    required this.label,
    required this.hint,
    required this.controller,
    required this.keyboard,
    this.inputFormatters,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF888780))),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboard,
              inputFormatters: inputFormatters,
              onChanged: onChanged,
              style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A1A)),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: Color(0xFFB4B2A9)),
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Preset extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _Preset({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD3D1C7), width: 0.5),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF378ADD),
                fontWeight: FontWeight.w500)),
      ),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoBox({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1EFE8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF888780)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF5F5E5A),
                  height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}
