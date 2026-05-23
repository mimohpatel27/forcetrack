import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../models/sensor_data.dart';
import '../services/mock_data_service.dart';
import '../services/pi_connection_service.dart';
import '../main.dart' show useMock;

class ForcePlateScreen extends StatefulWidget {
  const ForcePlateScreen({super.key});

  @override
  State<ForcePlateScreen> createState() => _ForcePlateScreenState();
}

class _ForcePlateScreenState extends State<ForcePlateScreen>
    with TickerProviderStateMixin {
  StreamSubscription<SensorData>? _sub;

  // Current values
  double _leftKg = 0;
  double _rightKg = 0;
  double _totalKg = 0;
  double _loadingRate = 0;
  double _impulse = 0;
  double _copPathMm = 0;
  double _symmetry = 0;

  // Rolling history — 60 samples
  final List<FlSpot> _leftHistory = [];
  final List<FlSpot> _rightHistory = [];
  final List<FlSpot> _totalHistory = [];
  int _sampleIdx = 0;
  static const int _maxSamples = 60;

  // COP path points
  final List<Offset> _copPoints = [];
  static const int _maxCopPoints = 30;

  // Stats
  double _peakLeft = 0;
  double _peakRight = 0;
  double _peakTotal = 0;
  int _sampleCount = 0;

  // Animations
  late AnimationController _balanceCtrl;
  late Animation<double> _leftAnim;
  late Animation<double> _rightAnim;
  double _prevLeftPct = 0.5;

  @override
  void initState() {
    super.initState();
    _balanceCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _leftAnim = const AlwaysStoppedAnimation(0.5);
    _rightAnim = const AlwaysStoppedAnimation(0.5);
    WidgetsBinding.instance.addPostFrameCallback((_) => _startListening());
  }

  void _startListening() {
    final Stream<SensorData> stream = useMock
        ? context.read<MockDataService>().stream
        : context.read<PiConnectionService>().dataStream;

    _sub = stream.listen((data) {
      final fp = data.forcePlate;
      final metrics = data.metrics;
      final total = fp.totalKg.clamp(0.1, 300.0);
      final leftPct = (fp.leftKg / total).clamp(0.0, 1.0);

      // Animate balance bar
      _leftAnim = Tween<double>(begin: _prevLeftPct, end: leftPct).animate(
          CurvedAnimation(parent: _balanceCtrl, curve: Curves.easeOutCubic));
      _balanceCtrl
        ..reset()
        ..forward();
      _prevLeftPct = leftPct;

      // COP path — simulate from balance ratio
      final copX = 0.3 + leftPct * 0.4 + _randNoise(0.03);
      final copY = 0.2 + (_sampleIdx % 20) / 20.0 * 0.6 + _randNoise(0.04);

      setState(() {
        _leftKg = fp.leftKg;
        _rightKg = fp.rightKg;
        _totalKg = fp.totalKg;
        _loadingRate = metrics.loadingRate;
        _copPathMm = metrics.copPathMm;
        _symmetry = metrics.symmetryIndex;
        _impulse = fp.totalKg * 9.81 * 0.245; // F × contact time

        // History
        final idx = _sampleIdx.toDouble();
        _leftHistory.add(FlSpot(idx, fp.leftKg * 9.81));
        _rightHistory.add(FlSpot(idx, fp.rightKg * 9.81));
        _totalHistory.add(FlSpot(idx, fp.totalKg * 9.81));
        _sampleIdx++;
        for (final list in [_leftHistory, _rightHistory, _totalHistory]) {
          if (list.length > _maxSamples) list.removeAt(0);
        }

        // COP
        _copPoints.add(Offset(copX, copY));
        if (_copPoints.length > _maxCopPoints) _copPoints.removeAt(0);

        // Peaks
        if (fp.leftKg > _peakLeft) _peakLeft = fp.leftKg;
        if (fp.rightKg > _peakRight) _peakRight = fp.rightKg;
        if (fp.totalKg > _peakTotal) _peakTotal = fp.totalKg;
        _sampleCount++;
      });
    });
  }

  double _randNoise(double scale) =>
      (Random().nextDouble() - 0.5) * scale * 2;

  @override
  void dispose() {
    _sub?.cancel();
    _balanceCtrl.dispose();
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
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildLiveForceRow(),
                  const SizedBox(height: 12),
                  _buildBalanceCard(),
                  const SizedBox(height: 12),
                  _buildForceChartCard(),
                  const SizedBox(height: 12),
                  _buildCopAndImpulseRow(),
                  const SizedBox(height: 12),
                  _buildMetricsCard(),
                  const SizedBox(height: 12),
                  _buildPeaksCard(),
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
                color: const Color(0xFF534AB7),
                borderRadius: BorderRadius.circular(9)),
            child: const Icon(Icons.monitor_weight_outlined,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Force Plate',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A))),
              Text('HX711 load cell • live',
                  style: TextStyle(fontSize: 11, color: Color(0xFF888780))),
            ],
          ),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: const Color(0xFFEEEDFE),
                borderRadius: BorderRadius.circular(20)),
            child: Row(children: [
              Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                      color: Color(0xFF534AB7),
                      shape: BoxShape.circle)),
              const SizedBox(width: 5),
              const Text('100 Hz',
                  style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF3C3489),
                      fontWeight: FontWeight.w500)),
            ]),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // Live force numbers row
  // ─────────────────────────────────────────
  Widget _buildLiveForceRow() {
    return Row(children: [
      _ForceCard(
          label: 'Left foot',
          kg: _leftKg,
          newton: _leftKg * 9.81,
          color: const Color(0xFF1D9E75)),
      const SizedBox(width: 10),
      _ForceCard(
          label: 'Right foot',
          kg: _rightKg,
          newton: _rightKg * 9.81,
          color: const Color(0xFF378ADD)),
      const SizedBox(width: 10),
      _ForceCard(
          label: 'Total',
          kg: _totalKg,
          newton: _totalKg * 9.81,
          color: const Color(0xFF534AB7)),
    ]);
  }

  // ─────────────────────────────────────────
  // Balance bar
  // ─────────────────────────────────────────
  Widget _buildBalanceCard() {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD3D1C7), width: 0.5)),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Load balance',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A))),
          const SizedBox(height: 14),
          AnimatedBuilder(
            animation: _leftAnim,
            builder: (_, __) {
              final lPct = _leftAnim.value;
              final rPct = 1.0 - lPct;
              final lLabel = '${(lPct * 100).toStringAsFixed(1)}%';
              final rLabel = '${(rPct * 100).toStringAsFixed(1)}%';
              final balanced = (lPct - 0.5).abs() < 0.05;
              final leftHeavy = lPct > 0.55;

              return Column(children: [
                Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Left $lLabel',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF1D9E75))),
                      Text('Right $rLabel',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF378ADD))),
                    ]),
                const SizedBox(height: 8),
                // Balance bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 20,
                    child: Row(children: [
                      Expanded(
                          flex: (lPct * 1000).round(),
                          child: Container(color: const Color(0xFF1D9E75))),
                      Expanded(
                          flex: (rPct * 1000).round(),
                          child: Container(color: const Color(0xFF378ADD))),
                    ]),
                  ),
                ),
                const SizedBox(height: 10),
                // Centre marker
                Stack(children: [
                  const Divider(
                      height: 1, thickness: 0.5, color: Color(0xFFD3D1C7)),
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                        width: 2,
                        height: 12,
                        color: const Color(0xFF888780)),
                  ),
                  // Dot indicator
                  AnimatedAlign(
                    alignment:
                        Alignment(lPct * 2 - 1.0, 0),
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                          color: lPct > 0.5
                              ? const Color(0xFF1D9E75)
                              : const Color(0xFF378ADD),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white, width: 2)),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                // Status label
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                        color: balanced
                            ? const Color(0xFFE1F5EE)
                            : const Color(0xFFFAEEDA),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      balanced
                          ? 'Well balanced'
                          : leftHeavy
                              ? 'More load on left foot'
                              : 'More load on right foot',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: balanced
                              ? const Color(0xFF085041)
                              : const Color(0xFF633806)),
                    ),
                  ),
                ),
              ]);
            },
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // Force chart
  // ─────────────────────────────────────────
  Widget _buildForceChartCard() {
    final hasData = _leftHistory.length >= 2;
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD3D1C7), width: 0.5)),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Force over time',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A))),
              Row(children: [
                _Legend(color: const Color(0xFF1D9E75), label: 'L'),
                const SizedBox(width: 8),
                _Legend(color: const Color(0xFF378ADD), label: 'R'),
                const SizedBox(width: 8),
                _Legend(color: const Color(0xFF534AB7), label: 'Total'),
              ]),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: hasData
                ? LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 150,
                        getDrawingHorizontalLine: (_) => const FlLine(
                            color: Color(0xFFF1EFE8), strokeWidth: 0.5),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 38,
                            interval: 150,
                            getTitlesWidget: (v, _) => Text(
                              '${v.toInt()}N',
                              style: const TextStyle(
                                  fontSize: 9,
                                  color: Color(0xFFB4B2A9)),
                            ),
                          ),
                        ),
                        bottomTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        _lineBar(_leftHistory, const Color(0xFF1D9E75)),
                        _lineBar(_rightHistory, const Color(0xFF378ADD)),
                        _lineBar(_totalHistory, const Color(0xFF534AB7),
                            width: 1.5),
                      ],
                      minY: 0,
                      maxY: (_peakTotal * 9.81 * 1.2).clamp(300, 1200),
                    ),
                    duration: const Duration(milliseconds: 100),
                  )
                : const Center(
                    child: Text('Collecting data…',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF888780)))),
          ),
        ],
      ),
    );
  }

  LineChartBarData _lineBar(List<FlSpot> spots, Color color,
      {double width = 1.5}) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: width,
      dotData: const FlDotData(show: false),
      belowBarData:
          BarAreaData(show: true, color: color.withOpacity(0.06)),
    );
  }

  // ─────────────────────────────────────────
  // COP path + impulse row
  // ─────────────────────────────────────────
  Widget _buildCopAndImpulseRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildCopCard()),
        const SizedBox(width: 10),
        Expanded(child: _buildImpulseCard()),
      ],
    );
  }

  Widget _buildCopCard() {
    return Container(
      height: 170,
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD3D1C7), width: 0.5)),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('COP path',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A))),
              Text('${_copPathMm.toStringAsFixed(0)} mm',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF534AB7))),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: CustomPaint(
              painter: _CopPathPainter(points: _copPoints),
              size: Size.infinite,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImpulseCard() {
    return Container(
      height: 170,
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD3D1C7), width: 0.5)),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Impulse',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A))),
          const SizedBox(height: 6),
          Text(
            '${_impulse.toStringAsFixed(0)} Ns',
            style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w300,
                color: Color(0xFF534AB7),
                letterSpacing: -1),
          ),
          const Text('Newton-seconds',
              style:
                  TextStyle(fontSize: 10, color: Color(0xFF888780))),
          const Spacer(),
          _MiniMetric(
              label: 'Loading rate',
              value:
                  '${_loadingRate.toStringAsFixed(1)} N/ms'),
          const SizedBox(height: 6),
          _MiniMetric(
              label: 'Symmetry',
              value: '${_symmetry.toStringAsFixed(1)}%'),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // Metrics card
  // ─────────────────────────────────────────
  Widget _buildMetricsCard() {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD3D1C7), width: 0.5)),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Live metrics',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A))),
          const SizedBox(height: 8),
          _MetricRow(
              icon: Icons.speed_outlined,
              label: 'Loading rate',
              value:
                  '${_loadingRate.toStringAsFixed(1)} N/ms',
              color: const Color(0xFFD85A30)),
          _MetricRow(
              icon: Icons.balance_outlined,
              label: 'Symmetry index',
              value: '${_symmetry.toStringAsFixed(1)}%',
              color: const Color(0xFF639922)),
          _MetricRow(
              icon: Icons.route_outlined,
              label: 'COP path length',
              value:
                  '${_copPathMm.toStringAsFixed(0)} mm',
              color: const Color(0xFF534AB7)),
          _MetricRow(
              icon: Icons.monitor_weight_outlined,
              label: 'Body weight',
              value:
                  '${_totalKg.toStringAsFixed(1)} kg',
              color: const Color(0xFF1D9E75)),
          _MetricRow(
              icon: Icons.bolt_outlined,
              label: 'Impulse',
              value: '${_impulse.toStringAsFixed(0)} Ns',
              color: const Color(0xFF378ADD)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────
  // Peaks card
  // ─────────────────────────────────────────
  Widget _buildPeaksCard() {
    return Container(
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFD3D1C7), width: 0.5)),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Session peaks',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A))),
          const SizedBox(height: 12),
          Row(children: [
            _PeakTile(
                label: 'Peak left',
                kg: _peakLeft,
                color: const Color(0xFF1D9E75)),
            const SizedBox(width: 10),
            _PeakTile(
                label: 'Peak right',
                kg: _peakRight,
                color: const Color(0xFF378ADD)),
            const SizedBox(width: 10),
            _PeakTile(
                label: 'Peak total',
                kg: _peakTotal,
                color: const Color(0xFF534AB7)),
          ]),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
                color: const Color(0xFFF1EFE8),
                borderRadius: BorderRadius.circular(8)),
            child: Row(children: [
              const Icon(Icons.info_outline,
                  size: 14, color: Color(0xFF888780)),
              const SizedBox(width: 8),
              Text(
                '$_sampleCount samples recorded this session',
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF5F5E5A)),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// COP path custom painter
// ─────────────────────────────────────────
class _CopPathPainter extends CustomPainter {
  final List<Offset> points;
  _CopPathPainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    // Trail
    final paint = Paint()
      ..color = const Color(0xFF534AB7).withOpacity(0.3)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final pt = Offset(points[i].dx * size.width, points[i].dy * size.height);
      if (i == 0) {
        path.moveTo(pt.dx, pt.dy);
      } else {
        // Fade older points
        final alpha = (i / points.length * 255).round();
        paint.color = const Color(0xFF534AB7).withOpacity(alpha / 255 * 0.7);
        canvas.drawLine(
          Offset(points[i - 1].dx * size.width,
              points[i - 1].dy * size.height),
          pt,
          paint,
        );
      }
    }

    // Current point dot
    if (points.isNotEmpty) {
      final last = points.last;
      canvas.drawCircle(
        Offset(last.dx * size.width, last.dy * size.height),
        5,
        Paint()..color = const Color(0xFF534AB7),
      );
      canvas.drawCircle(
        Offset(last.dx * size.width, last.dy * size.height),
        8,
        Paint()
          ..color = const Color(0xFF534AB7).withOpacity(0.2)
          ..style = PaintingStyle.fill,
      );
    }

    // Start point
    if (points.length > 1) {
      final first = points.first;
      canvas.drawCircle(
        Offset(first.dx * size.width, first.dy * size.height),
        3,
        Paint()..color = const Color(0xFFB4B2A9),
      );
    }
  }

  @override
  bool shouldRepaint(_CopPathPainter old) => old.points != points;
}

// ─────────────────────────────────────────
// Small reusable widgets
// ─────────────────────────────────────────
class _ForceCard extends StatelessWidget {
  final String label;
  final double kg, newton;
  final Color color;

  const _ForceCard({
    required this.label,
    required this.kg,
    required this.newton,
    required this.color,
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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: Color(0xFF888780))),
          const SizedBox(height: 4),
          Text('${newton.toStringAsFixed(0)} N',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: color)),
          Text('${kg.toStringAsFixed(1)} kg',
              style: const TextStyle(
                  fontSize: 10, color: Color(0xFFB4B2A9))),
        ]),
      ),
    );
  }
}

class _PeakTile extends StatelessWidget {
  final String label;
  final double kg;
  final Color color;

  const _PeakTile(
      {required this.label, required this.kg, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
            color: color.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: color.withOpacity(0.2), width: 0.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 9, color: Color(0xFF888780))),
          const SizedBox(height: 4),
          Text(
            '${(kg * 9.81).toStringAsFixed(0)} N',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color),
          ),
          Text('${kg.toStringAsFixed(1)} kg',
              style: const TextStyle(
                  fontSize: 9, color: Color(0xFFB4B2A9))),
        ]),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;

  const _MetricRow(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 10),
        Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: Color(0xFF5F5E5A)))),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color)),
      ]),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label, value;
  const _MiniMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 10, color: Color(0xFF888780))),
          Text(value,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF534AB7))),
        ]);
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
          width: 10,
          height: 3,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 3),
      Text(label,
          style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w500)),
    ]);
  }
}