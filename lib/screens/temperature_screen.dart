import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../models/sensor_data.dart';
import '../services/mock_data_service.dart';
import '../services/pi_connection_service.dart';
import '../main.dart' show useMock;

class TemperatureScreen extends StatefulWidget {
  const TemperatureScreen({super.key});

  @override
  State<TemperatureScreen> createState() => _TemperatureScreenState();
}

class _TemperatureScreenState extends State<TemperatureScreen>
    with TickerProviderStateMixin {
  StreamSubscription<SensorData>? _sub;

  // Current reading
  double _currentTemp = 0.0;
  String _unit = 'C';

  // History — last 60 samples (60 × 300ms = ~18 seconds of data)
  final List<FlSpot> _history = [];
  int _sampleIdx = 0;
  static const int _maxHistory = 60;

  // Stats
  double _minTemp = double.infinity;
  double _maxTemp = double.negativeInfinity;
  double _avgSum = 0.0;
  int _avgCount = 0;

  // Alert threshold
  double _alertThreshold = 37.5;
  bool _alertTriggered = false;

  // Needle animation
  late AnimationController _needleCtrl;
  late Animation<double> _needleAnim;
  double _prevTemp = 0.0;

  // Pulse animation for alert
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _needleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _needleAnim = Tween<double>(begin: 0, end: 0).animate(
        CurvedAnimation(parent: _needleCtrl, curve: Curves.easeOutCubic));
    _pulseCtrl = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 900),
        lowerBound: 0.85,
        upperBound: 1.0)
      ..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) => _startListening());
  }

  void _startListening() {
    final Stream<SensorData> stream = useMock
        ? context.read<MockDataService>().stream
        : context.read<PiConnectionService>().dataStream;

    _sub = stream.listen((data) {
      final newTemp = data.temperature.value;
      _animateNeedle(newTemp);

      setState(() {
        _currentTemp = newTemp;
        _unit = data.temperature.unit;

        // Rolling history
        _history.add(FlSpot(_sampleIdx.toDouble(), newTemp));
        _sampleIdx++;
        if (_history.length > _maxHistory) _history.removeAt(0);

        // Stats
        if (newTemp < _minTemp) _minTemp = newTemp;
        if (newTemp > _maxTemp) _maxTemp = newTemp;
        _avgSum += newTemp;
        _avgCount++;

        // Alert
        _alertTriggered = newTemp >= _alertThreshold;
      });
    });
  }

  void _animateNeedle(double newTemp) {
    _needleAnim = Tween<double>(begin: _prevTemp, end: newTemp).animate(
        CurvedAnimation(parent: _needleCtrl, curve: Curves.easeOutCubic));
    _needleCtrl
      ..reset()
      ..forward();
    _prevTemp = newTemp;
  }

  double get _avgTemp => _avgCount > 0 ? _avgSum / _avgCount : 0.0;

  String _tempStr(double v) => '${v.toStringAsFixed(1)}°$_unit';

  // Map temperature to color
  Color _tempColor(double t) {
    if (t < 35.0) return const Color(0xFF378ADD);
    if (t < 36.0) return const Color(0xFF1D9E75);
    if (t < 37.0) return const Color(0xFF639922);
    if (t < 37.5) return const Color(0xFFBA7517);
    return const Color(0xFFE24B4A);
  }

  String _tempLabel(double t) {
    if (t < 35.0) return 'Hypothermic';
    if (t < 36.0) return 'Below normal';
    if (t < 37.0) return 'Normal';
    if (t < 37.5) return 'Elevated';
    return 'High — alert';
  }

  @override
  void dispose() {
    _sub?.cancel();
    _needleCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F3),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            if (_alertTriggered) _buildAlertBanner(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildGaugeCard(),
                  const SizedBox(height: 12),
                  _buildStatsRow(),
                  const SizedBox(height: 12),
                  _buildTrendCard(),
                  const SizedBox(height: 12),
                  _buildThresholdCard(),
                  const SizedBox(height: 12),
                  _buildStatusCard(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // Top bar
  // ─────────────────────────────────────────
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: _tempColor(_currentTemp),
                borderRadius: BorderRadius.circular(9)),
            child: const Icon(Icons.thermostat_outlined,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Temperature',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A))),
              Text('DS18B20 sensor • live',
                  style: TextStyle(
                      fontSize: 11,
                      color: _currentTemp > 0
                          ? const Color(0xFF1D9E75)
                          : const Color(0xFF888780))),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: const Color(0xFFE1F5EE),
                borderRadius: BorderRadius.circular(20)),
            child: Row(
              children: [
                Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                        color: Color(0xFF1D9E75), shape: BoxShape.circle)),
                const SizedBox(width: 5),
                const Text('300ms',
                    style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF085041),
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // Alert banner
  // ─────────────────────────────────────────
  Widget _buildAlertBanner() {
    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, __) => Container(
        margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Color.lerp(const Color(0xFFFCEBEB), const Color(0xFFF7C1C1),
              _pulseCtrl.value - 0.85),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                size: 16, color: Color(0xFFA32D2D)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Temperature ${_tempStr(_currentTemp)} exceeds threshold ${_tempStr(_alertThreshold)}',
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFA32D2D),
                    fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // Gauge card — animated thermometer + big reading
  // ─────────────────────────────────────────
  Widget _buildGaugeCard() {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: const Color(0xFFD3D1C7), width: 0.5)),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Big temperature reading
          AnimatedBuilder(
            animation: _needleAnim,
            builder: (_, __) {
              final displayTemp = _needleAnim.value == 0.0 && _currentTemp > 0
                  ? _currentTemp
                  : _needleAnim.value;
              return Column(
                children: [
                  Text(
                    displayTemp > 0
                        ? '${displayTemp.toStringAsFixed(1)}°'
                        : '—°',
                    style: TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.w300,
                        color: _tempColor(displayTemp),
                        letterSpacing: -2),
                  ),
                  Text(
                    _unit == 'C' ? 'Celsius' : 'Fahrenheit',
                    style: const TextStyle(
                        fontSize: 13, color: Color(0xFF888780)),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          // Thermometer bar
          _buildThermometerBar(),
          const SizedBox(height: 14),
          // Status label
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: _tempColor(_currentTemp).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _currentTemp > 0 ? _tempLabel(_currentTemp) : 'Waiting for data',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: _tempColor(_currentTemp)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThermometerBar() {
    const double minScale = 34.0;
    const double maxScale = 40.0;
    final pct = _currentTemp > 0
        ? ((_currentTemp - minScale) / (maxScale - minScale)).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      children: [
        // Scale labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${minScale.toStringAsFixed(0)}°',
                style: const TextStyle(
                    fontSize: 10, color: Color(0xFF888780))),
            Text('Normal range',
                style: const TextStyle(
                    fontSize: 10, color: Color(0xFF888780))),
            Text('${maxScale.toStringAsFixed(0)}°',
                style: const TextStyle(
                    fontSize: 10, color: Color(0xFF888780))),
          ],
        ),
        const SizedBox(height: 6),
        // Gradient track
        Stack(
          children: [
            // Background track with color zones
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 12,
                child: Row(
                  children: [
                    Expanded(flex: 16, child: Container(color: const Color(0xFF85B7EB))),   // cold
                    Expanded(flex: 20, child: Container(color: const Color(0xFF1D9E75))),   // normal low
                    Expanded(flex: 20, child: Container(color: const Color(0xFF639922))),   // normal
                    Expanded(flex: 10, child: Container(color: const Color(0xFFBA7517))),   // elevated
                    Expanded(flex: 34, child: Container(color: const Color(0xFFE24B4A))),   // high
                  ],
                ),
              ),
            ),
            // Thumb indicator
            AnimatedPositioned(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutCubic,
              left: pct * (MediaQuery.of(context).size.width - 72) - 6,
              top: -2,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: _tempColor(_currentTemp), width: 2.5),
                    boxShadow: [
                      BoxShadow(
                          color: _tempColor(_currentTemp).withOpacity(0.3),
                          blurRadius: 4,
                          spreadRadius: 1),
                    ]),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ─────────────────────────────────────────
  // Stats row
  // ─────────────────────────────────────────
  Widget _buildStatsRow() {
    return Row(
      children: [
        _StatTile(
          label: 'Min',
          value: _minTemp.isInfinite ? '—' : _tempStr(_minTemp),
          color: const Color(0xFF378ADD),
          icon: Icons.arrow_downward_rounded,
        ),
        const SizedBox(width: 10),
        _StatTile(
          label: 'Avg',
          value: _avgCount > 0 ? _tempStr(_avgTemp) : '—',
          color: const Color(0xFF1D9E75),
          icon: Icons.drag_handle_rounded,
        ),
        const SizedBox(width: 10),
        _StatTile(
          label: 'Max',
          value: (_maxTemp.isInfinite && _maxTemp < 0) ? '—' : _tempStr(_maxTemp),
          color: const Color(0xFFE24B4A),
          icon: Icons.arrow_upward_rounded,
        ),
      ],
    );
  }

  // ─────────────────────────────────────────
  // Trend chart — 60s rolling window
  // ─────────────────────────────────────────
  Widget _buildTrendCard() {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: const Color(0xFFD3D1C7), width: 0.5)),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Trend',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A))),
              Text('last ~18 sec',
                  style: const TextStyle(
                      fontSize: 10, color: Color(0xFF888780))),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 130,
            child: _history.length < 2
                ? const Center(
                    child: Text('Collecting data…',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF888780))))
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 0.5,
                        getDrawingHorizontalLine: (_) => const FlLine(
                            color: Color(0xFFF1EFE8), strokeWidth: 0.5),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 36,
                            interval: 0.5,
                            getTitlesWidget: (v, _) => Text(
                              '${v.toStringAsFixed(1)}°',
                              style: const TextStyle(
                                  fontSize: 9,
                                  color: Color(0xFFB4B2A9)),
                            ),
                          ),
                        ),
                        rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      // Threshold line
                      extraLinesData: ExtraLinesData(horizontalLines: [
                        HorizontalLine(
                          y: _alertThreshold,
                          color: const Color(0xFFE24B4A).withOpacity(0.5),
                          strokeWidth: 1,
                          dashArray: [4, 4],
                          label: HorizontalLineLabel(
                            show: true,
                            alignment: Alignment.topRight,
                            style: const TextStyle(
                                fontSize: 9,
                                color: Color(0xFFE24B4A)),
                            labelResolver: (_) =>
                                'Alert ${_tempStr(_alertThreshold)}',
                          ),
                        ),
                      ]),
                      lineBarsData: [
                        LineChartBarData(
                          spots: _history,
                          isCurved: true,
                          curveSmoothness: 0.3,
                          color: _alertTriggered
                              ? const Color(0xFFE24B4A)
                              : const Color(0xFF1D9E75),
                          barWidth: 2,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: (_alertTriggered
                                    ? const Color(0xFFE24B4A)
                                    : const Color(0xFF1D9E75))
                                .withOpacity(0.08),
                          ),
                        ),
                      ],
                      minY: (_minTemp.isInfinite ? 35.5 : _minTemp - 0.3)
                          .clamp(34.0, 37.0),
                      maxY: ((_maxTemp.isInfinite && _maxTemp < 0) ? 37.5 : _maxTemp + 0.3)
                          .clamp(37.0, 40.0),
                    ),
                    duration: const Duration(milliseconds: 100),
                  ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // Threshold setter card
  // ─────────────────────────────────────────
  Widget _buildThresholdCard() {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: const Color(0xFFD3D1C7), width: 0.5)),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Alert threshold',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A))),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: const Color(0xFFFCEBEB),
                    borderRadius: BorderRadius.circular(20)),
                child: Text(
                  _tempStr(_alertThreshold),
                  style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFA32D2D),
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('Slide to set the temperature alert level',
              style: TextStyle(fontSize: 11, color: Color(0xFF888780))),
          const SizedBox(height: 10),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: const Color(0xFFE24B4A),
              inactiveTrackColor: const Color(0xFFF1EFE8),
              thumbColor: const Color(0xFFE24B4A),
              overlayColor: const Color(0xFFE24B4A).withOpacity(0.12),
              trackHeight: 4,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: _alertThreshold,
              min: 36.0,
              max: 39.5,
              divisions: 35,
              onChanged: (v) => setState(() => _alertThreshold = v),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('36.0°',
                  style: TextStyle(
                      fontSize: 10, color: Color(0xFFB4B2A9))),
              const Text('Normal limit',
                  style: TextStyle(
                      fontSize: 10, color: Color(0xFFB4B2A9))),
              const Text('39.5°',
                  style: TextStyle(
                      fontSize: 10, color: Color(0xFFB4B2A9))),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // Sensor status card
  // ─────────────────────────────────────────
  Widget _buildStatusCard() {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: const Color(0xFFD3D1C7), width: 0.5)),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Sensor info',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A))),
          const SizedBox(height: 12),
          _InfoRow(
              label: 'Sensor model', value: 'DS18B20'),
          _InfoRow(
              label: 'Interface', value: '1-Wire GPIO'),
          _InfoRow(
              label: 'Resolution', value: '12-bit (0.0625°C)'),
          _InfoRow(
              label: 'Sample rate', value: '300 ms'),
          _InfoRow(
              label: 'Source',
              value: useMock ? 'Mock data' : 'Live Pi sensor'),
          _InfoRow(
              label: 'Samples recorded',
              value: '$_avgCount'),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────
class _StatTile extends StatelessWidget {
  final String label, value;
  final Color color;
  final IconData icon;

  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: const Color(0xFFD3D1C7), width: 0.5)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 4),
                Text(label,
                    style: const TextStyle(
                        fontSize: 10, color: Color(0xFF888780))),
              ],
            ),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF888780)))),
          Text(value,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A1A1A))),
        ],
      ),
    );
  }
}