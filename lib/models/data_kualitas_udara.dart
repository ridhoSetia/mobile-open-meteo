/// Model data kualitas udara saat ini (blok "current" dari Open-Meteo).
///
/// Nilai polutan bertipe nullable: `null` berarti API tidak menyediakan
/// nilai tersebut (bukan 0).
class DataKualitasUdara {
  const DataKualitasUdara({
    required this.latitude,
    required this.longitude,
    required this.waktu,
    this.zonaWaktu,
    this.pm25,
    this.pm10,
    this.usAqi,
    this.europeanAqi,
    this.ozone,
    this.nitrogenDioksida,
    this.sulfurDioksida,
    this.karbonMonoksida,
    this.satuan = const <String, String>{},
  });

  /// Koordinat pusat grid model yang dipakai API (bisa berbeda beberapa km
  /// dari koordinat yang diminta).
  final double latitude;
  final double longitude;

  /// Waktu data (ISO 8601 tanpa offset, dalam zona waktu lokasi).
  final String waktu;

  /// Nama zona waktu dari API, misalnya "Asia/Makassar".
  final String? zonaWaktu;

  final double? pm25; // PM2.5
  final double? pm10; // PM10
  final double? usAqi; // US AQI
  final double? europeanAqi; // European AQI (skala berbeda dari US AQI)
  final double? ozone; // O3
  final double? nitrogenDioksida; // NO2
  final double? sulfurDioksida; // SO2
  final double? karbonMonoksida; // CO

  /// Satuan menurut respons API (`current_units`), dengan kunci nama field
  /// API, misalnya `satuan['pm2_5']`. Kosong bila API tidak menyediakannya.
  final Map<String, String> satuan;

  factory DataKualitasUdara.fromJson(Map<String, dynamic> json) {
    final current = json['current'];
    if (current is! Map<String, dynamic>) {
      throw const FormatException(
        "Field 'current' tidak ditemukan atau bukan objek JSON.",
      );
    }

    final waktu = current['time'];
    if (waktu is! String || waktu.isEmpty) {
      throw const FormatException(
        "Field 'current.time' tidak ditemukan atau bukan teks.",
      );
    }

    final satuan = <String, String>{};
    final unitMentah = json['current_units'];
    if (unitMentah is Map<String, dynamic>) {
      for (final entri in unitMentah.entries) {
        final nilai = entri.value;
        if (nilai is String) {
          satuan[entri.key] = nilai;
        }
      }
    }

    final zona = json['timezone'];

    return DataKualitasUdara(
      latitude: _angkaWajib(json, 'latitude'),
      longitude: _angkaWajib(json, 'longitude'),
      waktu: waktu,
      zonaWaktu: zona is String ? zona : null,
      pm25: _angkaOpsional(current, 'pm2_5'),
      pm10: _angkaOpsional(current, 'pm10'),
      usAqi: _angkaOpsional(current, 'us_aqi'),
      europeanAqi: _angkaOpsional(current, 'european_aqi'),
      ozone: _angkaOpsional(current, 'ozone'),
      nitrogenDioksida: _angkaOpsional(current, 'nitrogen_dioxide'),
      sulfurDioksida: _angkaOpsional(current, 'sulphur_dioxide'),
      karbonMonoksida: _angkaOpsional(current, 'carbon_monoxide'),
      satuan: satuan,
    );
  }

  /// Angka wajib: hilang atau bukan angka -> FormatException.
  static double _angkaWajib(Map<String, dynamic> sumber, String kunci) {
    final nilai = sumber[kunci];
    if (nilai is num) return nilai.toDouble();
    throw FormatException("Field '$kunci' tidak ditemukan atau bukan angka.");
  }

  /// Angka opsional: hilang/null -> null; bukan angka -> FormatException.
  /// JSON dapat berisi int maupun double, keduanya dikonversi lewat `num`.
  static double? _angkaOpsional(Map<String, dynamic> sumber, String kunci) {
    final nilai = sumber[kunci];
    if (nilai == null) return null;
    if (nilai is num) return nilai.toDouble();
    throw FormatException(
      "Nilai '$kunci' harus berupa angka, tetapi diterima "
      '${nilai.runtimeType}.',
    );
  }
}