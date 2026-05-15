import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../models/sensor_data.dart';
import '../services/mock_data_service.dart';
import '../services/pi_connection_service.dart';
import '../main.dart' show useMock;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  StreamSubscription<SensorData>? _sub;
  SensorData? _latest;

  // Rolling force history for chart (last 40 samples)
  final List<FlSpot> _leftForce = [];
  final List<FlSpot> _rightForce = [];
  int _sampleIndex = 0;
  static const int _maxSamples = 40;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startListening());
  }

  void _startListening() {
    final Stream<SensorData> stream = useMock
        ? context.read<MockDataService>().stream
        : context.read<PiConnectionService>().dataStream;
    _sub = stream.listen((data) {
      setState(() {
        _latest = data;
        final lN = data.forcePlate.leftKg * 9.81;
        final rN = data.forcePlate.rightKg * 9.81;
        _leftForce.add(FlSpot(_sampleIndex.toDouble(), lN));
        _rightForce.add(FlSpot(_sampleIndex.toDouble(), rN));
        _sampleIndex++;
        if (_leftForce.length > _maxSamples) {
          _leftForce.removeAt(0);
          _rightForce.removeAt(0);
        }
      });
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _tab.dispose();
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
              children: [
                _TopBar(svc: svc),
                _ConnectionBanner(svc: svc),
                _TabBar(controller: _tab),
                Expanded(
                  child: TabBarView(
                    controller: _tab,
                    children: [
                      _OverviewTab(data: _latest, leftForce: _leftForce, rightForce: _rightForce),
                      _PressureTab(data: _latest),
                      _MetricsTab(data: _latest),
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
}

// ─────────────────────────────────────────
// Top Bar
// ─────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final PiConnectionService svc;
  const _TopBar({required this.svc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: const Color(0xFF1D9E75), borderRadius: BorderRadius.circular(9)),
            child: const Icon(Icons.sensors, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ForceTrack', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
              Text('Live dashboard', style: TextStyle(fontSize: 11, color: Color(0xFF888780))),
            ],
          ),
          const Spacer(),
          if (svc.isConnected)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: const Color(0xFFE1F5EE), borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: [
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF1D9E75), shape: BoxShape.circle)),
                  const SizedBox(width: 5),
                  Text(svc.mode == ConnectionMode.wifi ? 'WiFi • 100Hz' : 'BLE • 100Hz',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF085041), fontWeight: FontWeight.w500)),
                ],
              ),
            ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 20, color: Color(0xFF888780)),
            onPressed: () {},
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Connection Banner
// ─────────────────────────────────────────
class _ConnectionBanner extends StatelessWidget {
  final PiConnectionService svc;
  const _ConnectionBanner({required this.svc});

  @override
  Widget build(BuildContext context) {
    if (svc.isConnected) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFFFCEBEB), borderRadius: BorderRadius.circular(9)),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 14, color: Color(0xFFA32D2D)),
          const SizedBox(width: 8),
          const Expanded(child: Text('Not connected — showing demo data', style: TextStyle(fontSize: 11, color: Color(0xFFA32D2D), fontWeight: FontWeight.w500))),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: const Text('Connect', style: TextStyle(fontSize: 11, color: Color(0xFF1D9E75), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Tab Bar
// ─────────────────────────────────────────
class _TabBar extends StatelessWidget {
  final TabController controller;
  const _TabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Container(
        decoration: BoxDecoration(color: const Color(0xFFE8E6DF), borderRadius: BorderRadius.circular(10)),
        child: TabBar(
          controller: controller,
          indicator: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFD3D1C7), width: 0.5)),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: const Color(0xFF1A1A1A),
          unselectedLabelColor: const Color(0xFF888780),
          labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          tabs: const [
            Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.dashboard_outlined, size: 13), SizedBox(width: 4), Text('Overview')])),
            Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.grid_view_outlined, size: 13), SizedBox(width: 4), Text('Pressure')])),
            Tab(child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.analytics_outlined, size: 13), SizedBox(width: 4), Text('Metrics')])),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Overview Tab
// ─────────────────────────────────────────
class _OverviewTab extends StatelessWidget {
  final SensorData? data;
  final List<FlSpot> leftForce;
  final List<FlSpot> rightForce;

  const _OverviewTab({required this.data, required this.leftForce, required this.rightForce});

  @override
  Widget build(BuildContext context) {
    final d = data;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Stat row
        Row(
          children: [
            _StatCard(label: 'Peak force L', value: d != null ? '${(d.forcePlate.leftKg * 9.81).toStringAsFixed(0)} N' : '— N', accent: const Color(0xFF1D9E75)),
            const SizedBox(width: 10),
            _StatCard(label: 'Peak force R', value: d != null ? '${(d.forcePlate.rightKg * 9.81).toStringAsFixed(0)} N' : '— N', accent: const Color(0xFF378ADD)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _StatCard(label: 'Symmetry', value: d != null ? '${d.metrics.symmetryIndex.toStringAsFixed(1)}%' : '—%', accent: const Color(0xFF639922)),
            const SizedBox(width: 10),
            _StatCard(label: 'Step freq', value: d != null ? '${d.metrics.stepFreq.toStringAsFixed(0)} spm' : '— spm', accent: const Color(0xFFBA7517)),
          ],
        ),
        const SizedBox(height: 14),
        // Force chart
        _SectionTitle(title: 'Force over time', subtitle: 'Left vs right foot (N)'),
        const SizedBox(height: 8),
        _ForceChart(leftSpots: leftForce, rightSpots: rightForce),
        const SizedBox(height: 14),
        // Mini foot heatmaps
        _SectionTitle(title: 'Pressure map', subtitle: 'Tap for full view'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _MiniHeatmap(label: 'Left', data: d?.fsr.left)),
            const SizedBox(width: 10),
            Expanded(child: _MiniHeatmap(label: 'Right', data: d?.fsr.right)),
          ],
        ),
        const SizedBox(height: 14),
        // Temperature + force plate row
        _SectionTitle(title: 'Sensor readings', subtitle: 'Live values'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _SensorCard(icon: Icons.thermostat_outlined, label: 'Temperature', value: d != null ? '${d.temperature.value.toStringAsFixed(1)}°C' : '—', color: const Color(0xFFD85A30))),
            const SizedBox(width: 10),
            Expanded(child: _SensorCard(icon: Icons.monitor_weight_outlined, label: 'Total load', value: d != null ? '${d.forcePlate.totalKg.toStringAsFixed(1)} kg' : '—', color: const Color(0xFF534AB7))),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────
// Pressure Tab
// ─────────────────────────────────────────
class _PressureTab extends StatelessWidget {
  final SensorData? data;
  const _PressureTab({required this.data});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _FullHeatmap(label: 'Left foot', data: data?.fsr.left, peak: data?.fsr.left?.expand((r) => r).fold<double>(0.0, max))),
            const SizedBox(width: 12),
            Expanded(child: _FullHeatmap(label: 'Right foot', data: data?.fsr.right, peak: data?.fsr.right?.expand((r) => r).fold<double>(0.0, max))),
          ],
        ),
        const SizedBox(height: 14),
        _SectionTitle(title: 'COP path', subtitle: 'Centre of pressure trajectory'),
        const SizedBox(height: 8),
        _CopPathCard(data: data),
        const SizedBox(height: 14),
        _SectionTitle(title: 'Balance', subtitle: 'Left / right load distribution'),
        const SizedBox(height: 8),
        _BalanceBar(data: data),
      ],
    );
  }
}

// ─────────────────────────────────────────
// Metrics Tab
// ─────────────────────────────────────────
class _MetricsTab extends StatelessWidget {
  final SensorData? data;
  const _MetricsTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final d = data;
    final metrics = [
      ('Peak force left', d != null ? '${(d.forcePlate.leftKg * 9.81).toStringAsFixed(0)} N' : '—', Icons.arrow_upward, const Color(0xFF1D9E75)),
      ('Peak force right', d != null ? '${(d.forcePlate.rightKg * 9.81).toStringAsFixed(0)} N' : '—', Icons.arrow_upward, const Color(0xFF378ADD)),
      ('Avg force left', d != null ? '${(d.forcePlate.leftKg * 9.81 * 0.55).toStringAsFixed(0)} N' : '—', Icons.show_chart, const Color(0xFF1D9E75)),
      ('Avg force right', d != null ? '${(d.forcePlate.rightKg * 9.81 * 0.55).toStringAsFixed(0)} N' : '—', Icons.show_chart, const Color(0xFF378ADD)),
      ('Step frequency', d != null ? '${d.metrics.stepFreq.toStringAsFixed(0)} spm' : '—', Icons.directions_walk, const Color(0xFFBA7517)),
      ('Symmetry index', d != null ? '${d.metrics.symmetryIndex.toStringAsFixed(1)}%' : '—', Icons.balance, const Color(0xFF639922)),
      ('COP path length', d != null ? '${d.metrics.copPathMm.toStringAsFixed(0)} mm' : '—', Icons.route, const Color(0xFF534AB7)),
      ('Loading rate', d != null ? '${d.metrics.loadingRate.toStringAsFixed(1)} N/ms' : '—', Icons.speed, const Color(0xFFD85A30)),
      ('Temperature', d != null ? '${d.temperature.value.toStringAsFixed(1)}°C' : '—', Icons.thermostat_outlined, const Color(0xFFD85A30)),
      ('Total load', d != null ? '${d.forcePlate.totalKg.toStringAsFixed(1)} kg' : '—', Icons.monitor_weight_outlined, const Color(0xFF534AB7)),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ...metrics.map((m) => _MetricRow(label: m.$1, value: m.$2, icon: m.$3, color: m.$4)),
        const SizedBox(height: 8),
        _ExportButton(),
      ],
    );
  }
}

// ─────────────────────────────────────────
// Force Line Chart
// ─────────────────────────────────────────
class _ForceChart extends StatelessWidget {
  final List<FlSpot> leftSpots;
  final List<FlSpot> rightSpots;

  const _ForceChart({required this.leftSpots, required this.rightSpots});

  @override
  Widget build(BuildContext context) {
    final hasData = leftSpots.isNotEmpty;
    final demo = List.generate(20, (i) => FlSpot(i.toDouble(), 300 + sin(i * 0.5) * 80 + i * 4.0));
    final demoR = List.generate(20, (i) => FlSpot(i.toDouble(), 280 + cos(i * 0.5) * 70 + i * 3.5));

    return Container(
      height: 140,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFD3D1C7), width: 0.5)),
      padding: const EdgeInsets.fromLTRB(8, 12, 12, 8),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 200,
              getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFF1EFE8), strokeWidth: 0.5)),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 32,
                getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(fontSize: 9, color: Color(0xFFB4B2A9))))),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(spots: hasData ? leftSpots : demo, isCurved: true, color: const Color(0xFF1D9E75),
                barWidth: 2, dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(show: true, color: const Color(0xFF1D9E75).withOpacity(0.08))),
            LineChartBarData(spots: hasData ? rightSpots : demoR, isCurved: true, color: const Color(0xFF378ADD),
                barWidth: 2, dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(show: true, color: const Color(0xFF378ADD).withOpacity(0.06))),
          ],
        ),
        duration: const Duration(milliseconds: 150),
      ),
    );
  }
}

// ─────────────────────────────────────────
// Mini Heatmap (overview)
// ─────────────────────────────────────────
class _MiniHeatmap extends StatelessWidget {
  final String label;
  final List<List<double>>? data;
  const _MiniHeatmap({required this.label, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFD3D1C7), width: 0.5)),
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF1A1A1A))),
          const SizedBox(height: 8),
          SizedBox(height: 100, child: CustomPaint(painter: _HeatmapPainter(data: data), size: Size.infinite)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Peak: ${data != null ? data!.expand((r) => r).fold(0.0, max).toStringAsFixed(0) : '—'}', style: const TextStyle(fontSize: 9, color: Color(0xFF888780))),
              Text('Avg: ${data != null ? (data!.expand((r) => r).reduce((a, b) => a + b) / (data!.length * data![0].length)).toStringAsFixed(0) : '—'}', style: const TextStyle(fontSize: 9, color: Color(0xFF888780))),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Full Heatmap (pressure tab)
// ─────────────────────────────────────────
class _FullHeatmap extends StatelessWidget {
  final String label;
  final List<List<double>>? data;
  final double? peak;
  const _FullHeatmap({required this.label, required this.data, required this.peak});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFD3D1C7), width: 0.5)),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
          const SizedBox(height: 10),
          SizedBox(height: 180, child: CustomPaint(painter: _HeatmapPainter(data: data, showValues: true), size: Size.infinite)),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Peak: ${peak?.toStringAsFixed(0) ?? '—'}', style: const TextStyle(fontSize: 10, color: Color(0xFF888780))),
            _ColorScale(),
          ]),
        ],
      ),
    );
  }
}

class _ColorScale extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const colors = [Color(0xFF3266AD), Color(0xFF5DCAA5), Color(0xFFEF9F27), Color(0xFFE24B4A)];
    return Row(children: [
      const Text('Low', style: TextStyle(fontSize: 9, color: Color(0xFFB4B2A9))),
      const SizedBox(width: 4),
      Row(children: colors.map((c) => Container(width: 12, height: 6, color: c)).toList()),
      const SizedBox(width: 4),
      const Text('High', style: TextStyle(fontSize: 9, color: Color(0xFFB4B2A9))),
    ]);
  }
}

// ─────────────────────────────────────────
// Heatmap Painter
// ─────────────────────────────────────────
class _HeatmapPainter extends CustomPainter {
  final List<List<double>>? data;
  final bool showValues;

  _HeatmapPainter({this.data, this.showValues = false});

  Color _heatColor(double t) {
    if (t < 0.25) return Color.lerp(const Color(0xFF3266AD), const Color(0xFF5DCAA5), t / 0.25)!;
    if (t < 0.5)  return Color.lerp(const Color(0xFF5DCAA5), const Color(0xFFEF9F27), (t - 0.25) / 0.25)!;
    if (t < 0.75) return Color.lerp(const Color(0xFFEF9F27), const Color(0xFFE24B4A), (t - 0.5) / 0.25)!;
    return Color.lerp(const Color(0xFFE24B4A), const Color(0xFFD4537E), (t - 0.75) / 0.25)!;
  }

  // Foot silhouette path scaled to given rect
  Path _footPath(Rect r) {
    final p = Path();
    final kx = r.width, ky = r.height;
    final ox = r.left, oy = r.top;
    final pts = [
      [.35,.06],[.5,.04],[.65,.06],[.72,.12],[.70,.20],
      [.72,.30],[.74,.40],[.72,.50],[.70,.60],[.68,.70],
      [.65,.78],[.55,.84],[.45,.84],[.35,.78],
      [.28,.68],[.26,.56],[.28,.44],[.30,.32],[.30,.20],[.33,.12],
    ];
    p.moveTo(ox + pts[0][0]*kx, oy + pts[0][1]*ky);
    for (var i = 1; i < pts.length; i++) {
      p.lineTo(ox + pts[i][0]*kx, oy + pts[i][1]*ky);
    }
    p.close();
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final grid = data ?? List.generate(8, (r) => List.generate(4, (c) {
      final base = [40.0, 80.0, 130.0, 200.0, 280.0, 320.0, 290.0, 160.0][r];
      return base * (0.7 + (r * 4 + c) % 7 * 0.08);
    }));

    final maxVal = grid.expand((r) => r).fold(0.0, max).clamp(1.0, double.infinity);
    final rows = grid.length, cols = grid[0].length;
    final cellW = size.width * 0.5 / cols;
    final cellH = size.height * 0.86 / rows;
    final startX = size.width * 0.25, startY = size.height * 0.06;

    final footRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final footPath = _footPath(footRect);

    // Clip to foot shape
    canvas.save();
    canvas.clipPath(footPath);

    final paint = Paint();
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final t = grid[r][c] / maxVal;
        paint.color = _heatColor(t.clamp(0.0, 1.0));
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(startX + c * cellW + 1, startY + r * cellH + 1, cellW - 2, cellH - 2),
          const Radius.circular(2),
        );
        canvas.drawRRect(rect, paint);

        if (showValues) {
          final tp = TextPainter(
            text: TextSpan(text: grid[r][c].toStringAsFixed(0), style: const TextStyle(fontSize: 6, color: Colors.white, fontWeight: FontWeight.w600)),
            textDirection: TextDirection.ltr,
          )..layout();
          tp.paint(canvas, Offset(startX + c * cellW + cellW / 2 - tp.width / 2, startY + r * cellH + cellH / 2 - tp.height / 2));
        }
      }
    }
    canvas.restore();

    // Foot outline
    paint
      ..color = const Color(0xFFB4B2A9).withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    canvas.drawPath(footPath, paint);
  }

  @override
  bool shouldRepaint(_HeatmapPainter old) => old.data != data;
}

// ─────────────────────────────────────────
// COP Path Card
// ─────────────────────────────────────────
class _CopPathCard extends StatelessWidget {
  final SensorData? data;
  const _CopPathCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFD3D1C7), width: 0.5)),
      padding: const EdgeInsets.all(12),
      child: CustomPaint(painter: _CopPainter()),
    );
  }
}

class _CopPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1D9E75).withOpacity(0.15)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    final pts = [
      Offset(size.width * .3, size.height * .8),
      Offset(size.width * .35, size.height * .6),
      Offset(size.width * .4, size.height * .4),
      Offset(size.width * .45, size.height * .25),
      Offset(size.width * .5, size.height * .2),
      Offset(size.width * .55, size.height * .25),
      Offset(size.width * .6, size.height * .4),
      Offset(size.width * .65, size.height * .6),
      Offset(size.width * .7, size.height * .8),
    ];

    path.moveTo(pts[0].dx, pts[0].dy);
    for (var i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }

    canvas.drawPath(path, paint..color = const Color(0xFF1D9E75).withOpacity(0.2));
    canvas.drawPath(path, paint..color = const Color(0xFF1D9E75)..strokeWidth = 1.5..style = PaintingStyle.stroke);

    // Dot at current position
    canvas.drawCircle(pts.last, 4, Paint()..color = const Color(0xFF1D9E75));
    canvas.drawCircle(pts.first, 3, Paint()..color = const Color(0xFFB4B2A9));
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────
// Balance Bar
// ─────────────────────────────────────────
class _BalanceBar extends StatelessWidget {
  final SensorData? data;
  const _BalanceBar({required this.data});

  @override
  Widget build(BuildContext context) {
    final total = (data?.forcePlate.totalKg ?? 70.0).clamp(0.1, 200.0);
    final leftPct = ((data?.forcePlate.leftKg ?? 34.0) / total).clamp(0.0, 1.0);

    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFD3D1C7), width: 0.5)),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Left ${(leftPct * 100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF1D9E75))),
            Text('Right ${((1 - leftPct) * 100).toStringAsFixed(1)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF378ADD))),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 14,
              child: Row(
                children: [
                  Expanded(flex: (leftPct * 100).round(), child: Container(color: const Color(0xFF1D9E75))),
                  Expanded(flex: ((1 - leftPct) * 100).round(), child: Container(color: const Color(0xFF378ADD))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(child: Text(leftPct > 0.55 ? 'More load on left foot' : leftPct < 0.45 ? 'More load on right foot' : 'Well balanced',
              style: const TextStyle(fontSize: 10, color: Color(0xFF888780)))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label, value;
  final Color accent;
  const _StatCard({required this.label, required this.value, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFD3D1C7), width: 0.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF888780))),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: accent)),
        ]),
      ),
    );
  }
}

class _SensorCard extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _SensorCard({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFD3D1C7), width: 0.5)),
      child: Row(children: [
        Container(width: 32, height: 32, decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: color)),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF888780))),
          Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
        ]),
      ]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title, subtitle;
  const _SectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
      Text(subtitle, style: const TextStyle(fontSize: 10, color: Color(0xFF888780))),
    ]);
  }
}

class _MetricRow extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  const _MetricRow({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFD3D1C7), width: 0.5)),
      child: Row(children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF5F5E5A)))),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}

class _ExportButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(color: const Color(0xFFF1EFE8), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFD3D1C7), width: 0.5)),
      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.download_outlined, size: 16, color: Color(0xFF5F5E5A)),
        SizedBox(width: 8),
        Text('Export session as CSV', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF5F5E5A))),
      ]),
    );
  }
}
