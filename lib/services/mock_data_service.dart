import 'dart:async';
import 'dart:math';
import '../models/sensor_data.dart';

/// Generates realistic FSR, temperature and force plate data every 300ms.
/// Simulates a real walking gait cycle — heel strike → midstance → toe-off.
/// Drop-in replacement for PiDataService: same Stream<SensorData> output.

class MockDataService {
  static const Duration _interval = Duration(milliseconds: 300);
  static const bool useMock = true; // flip to false when Pi is ready

  final _random = Random();
  final _controller = StreamController<SensorData>.broadcast();
  Timer? _timer;

  // Gait cycle state (0.0 → 1.0 → 0.0 repeating)
  double _gaitPhase = 0.0;
  double _gaitSpeed = 0.06; // how fast gait cycle progresses per tick

  // Walking symmetry drift — simulates slight L/R imbalance over time
  double _symmetryDrift = 0.0;
  double _driftDirection = 1.0;

  // Temperature state — slow natural variation
  double _tempBase = 36.4;
  double _tempDrift = 0.0;

  // Step detection state
  int _stepCount = 0;
  double _lastGaitPeak = 0.0;
  bool _inStance = false;
  final List<double> _stepTimestamps = [];

  Stream<SensorData> get stream => _controller.stream;
  bool get isRunning => _timer?.isActive ?? false;

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => _emit());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
    _controller.close();
  }

  void _emit() {
    _updateGaitPhase();
    _updateTemperature();
    _updateSymmetryDrift();

    final data = SensorData(
      timestamp: DateTime.now().millisecondsSinceEpoch / 1000.0,
      fsr: _generateFsr(),
      temperature: _generateTemperature(),
      forcePlate: _generateForcePlate(),
      metrics: _generateMetrics(),
    );

    if (!_controller.isClosed) {
      _controller.add(data);
    }
  }

  // ─────────────────────────────────────────
  // Gait phase — drives all pressure values
  // Simulates: heel strike (0.0) → midstance (0.4) → toe-off (0.8) → swing (1.0)
  // ─────────────────────────────────────────
  void _updateGaitPhase() {
    _gaitPhase += _gaitSpeed + _noise(0.005);

    if (_gaitPhase >= 1.0) {
      _gaitPhase = 0.0;
      _stepCount++;
      _stepTimestamps.add(DateTime.now().millisecondsSinceEpoch / 1000.0);
      if (_stepTimestamps.length > 10) _stepTimestamps.removeAt(0);
    }

    // Detect stance phase entry
    final forceNow = _gaitForceMultiplier(_gaitPhase);
    if (!_inStance && forceNow > 0.5) _inStance = true;
    if (_inStance && forceNow < 0.1) _inStance = false;
  }

  void _updateTemperature() {
    _tempDrift += _noise(0.02);
    _tempDrift = _tempDrift.clamp(-0.8, 0.8);
    _tempBase = (_tempBase + _noise(0.005)).clamp(35.8, 37.4);
  }

  void _updateSymmetryDrift() {
    _symmetryDrift += _driftDirection * 0.003;
    if (_symmetryDrift.abs() > 0.08) _driftDirection *= -1;
  }

  // ─────────────────────────────────────────
  // Force multiplier — the gait waveform
  // Produces double-hump shape: heel strike + push-off
  // ─────────────────────────────────────────
  double _gaitForceMultiplier(double phase) {
    // Heel strike hump (0.0 - 0.35)
    final heelHump = phase < 0.35
        ? sin(phase / 0.35 * pi) * 0.85
        : 0.0;

    // Push-off hump (0.55 - 0.85)
    final pushHump = (phase > 0.55 && phase < 0.85)
        ? sin((phase - 0.55) / 0.30 * pi) * 1.0
        : 0.0;

    return max(heelHump, pushHump).clamp(0.0, 1.0);
  }

  // ─────────────────────────────────────────
  // FSR — 4×4 grids for left and right foot
  // Pressure zones match real foot anatomy:
  //   Row 0-1: toes (light)
  //   Row 2-3: ball of foot (heavy during push-off)
  //   Row 4-5: midfoot arch (light — arch relief)
  //   Row 6-7: heel (heavy during heel strike)
  // ─────────────────────────────────────────
  FsrData _generateFsr() {
    final fm = _gaitForceMultiplier(_gaitPhase);
    final heelPhase = _gaitPhase < 0.35 ? (_gaitPhase / 0.35) : 0.0;
    final pushPhase = (_gaitPhase > 0.55 && _gaitPhase < 0.85)
        ? ((_gaitPhase - 0.55) / 0.30)
        : 0.0;

    // Zone base pressures for left foot (Newtons mapped to 0-500 sensor units)
    //                        C0   C1   C2   C3
    final leftZones = [
      [0.10, 0.12, 0.12, 0.08], // R0 — little toes
      [0.15, 0.20, 0.20, 0.12], // R1 — toes
      [0.30, 0.50, 0.50, 0.25], // R2 — ball (push-off zone)
      [0.35, 0.55, 0.55, 0.30], // R3 — ball peak
      [0.10, 0.15, 0.15, 0.10], // R4 — arch (naturally low)
      [0.08, 0.12, 0.12, 0.08], // R5 — arch
      [0.40, 0.60, 0.55, 0.35], // R6 — heel (heel-strike zone)
      [0.45, 0.65, 0.60, 0.40], // R7 — heel peak
    ];

    // Right foot — slight mirror asymmetry
    final rightZones = [
      [0.08, 0.12, 0.14, 0.10],
      [0.12, 0.20, 0.22, 0.14],
      [0.25, 0.48, 0.52, 0.28],
      [0.30, 0.52, 0.58, 0.32],
      [0.08, 0.14, 0.16, 0.10],
      [0.06, 0.10, 0.14, 0.09],
      [0.38, 0.58, 0.60, 0.38],
      [0.42, 0.62, 0.64, 0.42],
    ];

    List<List<double>> buildGrid(List<List<double>> zones, double side) {
      return List.generate(8, (r) {
        return List.generate(4, (c) {
          final base = zones[r][c];

          // Apply gait phase: heel rows activate on heel strike,
          // ball rows activate on push-off
          double zoneMultiplier;
          if (r >= 6) {
            // Heel rows
            zoneMultiplier = 0.1 + heelPhase * 0.9;
          } else if (r >= 2 && r <= 3) {
            // Ball rows
            zoneMultiplier = 0.15 + pushPhase * 0.85 + fm * 0.3;
          } else if (r >= 4 && r <= 5) {
            // Arch — stays low always
            zoneMultiplier = 0.05 + fm * 0.1;
          } else {
            // Toes
            zoneMultiplier = 0.05 + pushPhase * 0.6;
          }

          final raw = base * zoneMultiplier * 500.0 * side;
          final noisy = raw + _noise(raw * 0.08);
          return noisy.clamp(5.0, 500.0);
        });
      });
    }

    // Left foot is slightly heavier (symmetryDrift)
    final leftSide = 1.0 + _symmetryDrift;
    final rightSide = 1.0 - _symmetryDrift;

    return FsrData(
      left: buildGrid(leftZones, leftSide),
      right: buildGrid(rightZones, rightSide),
    );
  }

  // ─────────────────────────────────────────
  // Temperature — DS18B20 sensor simulation
  // Slow drift with tiny random noise (~±0.1°C)
  // ─────────────────────────────────────────
  TemperatureData _generateTemperature() {
    final value = _tempBase + _tempDrift;
    return TemperatureData(
      value: double.parse(value.toStringAsFixed(1)),
      unit: 'C',
    );
  }

  // ─────────────────────────────────────────
  // Force plate — HX711 load cell simulation
  // Left + right loads follow gait cycle
  // Total should equal body weight (~70kg)
  // ─────────────────────────────────────────
  ForcePlateData _generateForcePlate() {
    final fm = _gaitForceMultiplier(_gaitPhase);
    const bodyWeight = 70.0; // kg

    // During swing phase both feet may share load
    // During stance one foot carries ~60-100% of BW
    final leftRatio = 0.5 + _symmetryDrift + fm * 0.3 + _noise(0.02);
    final rightRatio = 1.0 - leftRatio + _noise(0.01);

    final totalLoad = bodyWeight * (0.85 + fm * 0.25 + _noise(0.02));

    return ForcePlateData(
      leftKg: double.parse((totalLoad * leftRatio.clamp(0.2, 0.85)).toStringAsFixed(1)),
      rightKg: double.parse((totalLoad * rightRatio.clamp(0.2, 0.85)).toStringAsFixed(1)),
      totalKg: double.parse(totalLoad.toStringAsFixed(1)),
    );
  }

  // ─────────────────────────────────────────
  // Gait metrics — computed from state
  // ─────────────────────────────────────────
  GaitMetrics _generateMetrics() {
    // Step frequency from recent step timestamps
    double stepFreq = 110.0;
    if (_stepTimestamps.length >= 2) {
      final span = _stepTimestamps.last - _stepTimestamps.first;
      final steps = _stepTimestamps.length - 1;
      if (span > 0) {
        stepFreq = (steps / span * 60.0).clamp(80.0, 200.0);
      }
    }

    // Symmetry index: 100% = perfect, drifts with _symmetryDrift
    final symmetry = (100.0 - (_symmetryDrift.abs() * 200.0) + _noise(0.5)).clamp(88.0, 99.9);

    // COP path length — varies with step frequency
    final copPath = 160.0 + stepFreq * 0.15 + _noise(5.0);

    // Loading rate — peak force per time, influenced by gait phase
    final loadingRate = 4.2 + _gaitForceMultiplier(_gaitPhase) * 1.2 + _noise(0.15);

    // Pronation angle — slight natural variation
    final pronation = 7.8 + _symmetryDrift * 20 + _noise(0.3);

    // Stance phase — % of gait cycle in stance (normally ~60%)
    final stance = 58.0 + _noise(2.0);

    // Impulse — integral of force over contact time
    final impulse = 155.0 + _gaitForceMultiplier(_gaitPhase) * 25.0 + _noise(4.0);

    return GaitMetrics(
      symmetryIndex: double.parse(symmetry.toStringAsFixed(1)),
      stepFreq: double.parse(stepFreq.toStringAsFixed(0)),
      loadingRate: double.parse(loadingRate.toStringAsFixed(1)),
      copPathMm: double.parse(copPath.toStringAsFixed(0)),
    );
  }

  // ─────────────────────────────────────────
  // Utility — gaussian-ish noise
  // ─────────────────────────────────────────
  double _noise(double scale) {
    // Box-Muller approximation using sum of uniforms
    final u = (_random.nextDouble() + _random.nextDouble() +
            _random.nextDouble() + _random.nextDouble()) /
        4.0 -
        0.5;
    return u * scale * 2.0;
  }
}
