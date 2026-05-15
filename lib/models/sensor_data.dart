class SensorData {
  final double timestamp;
  final FsrData fsr;
  final TemperatureData temperature;
  final ForcePlateData forcePlate;
  final GaitMetrics metrics;

  SensorData({
    required this.timestamp,
    required this.fsr,
    required this.temperature,
    required this.forcePlate,
    required this.metrics,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      timestamp: (json['timestamp'] as num).toDouble(),
      fsr: FsrData.fromJson(json['fsr'] as Map<String, dynamic>),
      temperature: TemperatureData.fromJson(
          json['temperature'] as Map<String, dynamic>),
      forcePlate:
          ForcePlateData.fromJson(json['force_plate'] as Map<String, dynamic>),
      metrics: GaitMetrics.fromJson(json['metrics'] as Map<String, dynamic>),
    );
  }
}

class FsrData {
  final List<List<double>> left;
  final List<List<double>> right;

  FsrData({required this.left, required this.right});

  factory FsrData.fromJson(Map<String, dynamic> json) {
    List<List<double>> parseGrid(dynamic raw) {
      return (raw as List)
          .map((row) =>
              (row as List).map((v) => (v as num).toDouble()).toList())
          .toList();
    }

    return FsrData(
      left: parseGrid(json['left']),
      right: parseGrid(json['right']),
    );
  }
}

class TemperatureData {
  final double value;
  final String unit;

  TemperatureData({required this.value, required this.unit});

  factory TemperatureData.fromJson(Map<String, dynamic> json) {
    return TemperatureData(
      value: (json['value'] as num).toDouble(),
      unit: json['unit'] as String,
    );
  }
}

class ForcePlateData {
  final double leftKg;
  final double rightKg;
  final double totalKg;

  ForcePlateData(
      {required this.leftKg, required this.rightKg, required this.totalKg});

  factory ForcePlateData.fromJson(Map<String, dynamic> json) {
    return ForcePlateData(
      leftKg: (json['left_kg'] as num).toDouble(),
      rightKg: (json['right_kg'] as num).toDouble(),
      totalKg: (json['total_kg'] as num).toDouble(),
    );
  }
}

class GaitMetrics {
  final double symmetryIndex;
  final double stepFreq;
  final double loadingRate;
  final double copPathMm;

  GaitMetrics({
    required this.symmetryIndex,
    required this.stepFreq,
    required this.loadingRate,
    required this.copPathMm,
  });

  factory GaitMetrics.fromJson(Map<String, dynamic> json) {
    return GaitMetrics(
      symmetryIndex: (json['symmetry_index'] as num).toDouble(),
      stepFreq: (json['step_freq'] as num).toDouble(),
      loadingRate: (json['loading_rate'] as num).toDouble(),
      copPathMm: (json['cop_path_mm'] as num).toDouble(),
    );
  }
}
