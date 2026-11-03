import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../models/data_kualitas_udara.dart';
import '../repositories/repositori_kualitas_udara.dart';
import '../services/layanan_kualitas_udara.dart';

/// Hasil satu pengujian.
class HasilUji {
  const HasilUji({
    required this.nama,
    required this.lulus,
    required this.keterangan,
  });

  final String nama;
  final bool lulus;
  final String keterangan;
}

class KegagalanPengujian implements Exception {
  const KegagalanPengujian(this.pesan);

  final String pesan;

  @override
  String toString() => pesan;
}

const double _lat = -0.5022;
const double _lon = 117.1536;
const String _waktuContoh = '2026-10-27T14:00';

// ---------------------------------------------------------------------------
// Pembantu
// ---------------------------------------------------------------------------

void _pastikan(bool kondisi, String pesan) {
  if (!kondisi) throw KegagalanPengujian(pesan);
}

/// Menjalankan [aksi] dan mengembalikan exception bertipe T yang dilempar.
Future<T> _harapkan<T extends Object>(Future<dynamic> Function() aksi) async {
  try {
    await aksi();
  } on T catch (e) {
    return e;
  } catch (e) {
    throw KegagalanPengujian(
      'Diharapkan $T tetapi diterima ${e.runtimeType}: $e',
    );
  }
  throw KegagalanPengujian('Diharapkan $T tetapi tidak ada exception.');
}

RepositoriKualitasUdara _buatRepositori(
  MockClientHandler handler, {
  Duration batasWaktu = const Duration(seconds: 2),
}) {
  return RepositoriKualitasUdara(
    LayananKualitasUdara(client: MockClient(handler), batasWaktu: batasWaktu),
  );
}

/// Repositori yang selalu menjawab 200 dengan [body] sebagai JSON.
RepositoriKualitasUdara _repositoriDenganBody(Object body) {
  return _buatRepositori((request) async => _jawabJson(body));
}

http.Response _jawabJson(Object isi, {int status = 200}) {
  return http.Response(
    jsonEncode(isi),
    status,
    headers: const {'content-type': 'application/json; charset=utf-8'},
  );
}

Future<DataKualitasUdara> _ambil(RepositoriKualitasUdara repo) {
  return repo.ambilDataKualitasUdara(latitude: _lat, longitude: _lon);
}

/// Isi blok `current` contoh (struktur mengikuti Open-Meteo; nilai fiktif).
/// Campuran int dan double disengaja karena API dapat mengirim keduanya.
Map<String, dynamic> _currentContoh() => <String, dynamic>{
      'time': _waktuContoh,
      'interval': 900,
      'pm10': 22.4,
      'pm2_5': 15.8,
      'carbon_monoxide': 212,
      'nitrogen_dioxide': 5.2,
      'sulphur_dioxide': 3.1,
      'ozone': 68,
      'european_aqi': 41,
      'us_aqi': 58,
    };

/// JSON tiruan: latitude/longitude adalah pusat grid model.
Map<String, dynamic> _bodyContoh({
  Map<String, dynamic>? current,
  bool denganUnit = true,
}) {
  final body = <String, dynamic>{
    'latitude': -0.5,
    'longitude': 117.25,
    'generationtime_ms': 0.42,
    'utc_offset_seconds': 28800,
    'timezone': 'Asia/Makassar',
    'timezone_abbreviation': 'GMT+8',
    'elevation': 20.0,
    'current_units': <String, dynamic>{
      'time': 'iso8601',
      'interval': 'seconds',
      'pm10': 'μg/m³',
      'pm2_5': 'μg/m³',
      'carbon_monoxide': 'μg/m³',
      'nitrogen_dioxide': 'μg/m³',
      'sulphur_dioxide': 'μg/m³',
      'ozone': 'μg/m³',
      'european_aqi': 'european_aqi',
      'us_aqi': 'USAQI',
    },
    'current': current ?? _currentContoh(),
  };
  if (!denganUnit) body.remove('current_units');
  return body;
}

/// Menjalankan satu panggilan dan mengembalikan request yang diterima mock.
Future<http.Request> _tangkapRequest() async {
  http.Request? diterima;
  final repo = _buatRepositori((request) async {
    diterima = request;
    return _jawabJson(_bodyContoh());
  });
  await _ambil(repo);
  final hasil = diterima;
  _pastikan(hasil != null, 'MockClient tidak menerima request apa pun.');
  return hasil!;
}

// ---------------------------------------------------------------------------
// Pengujian
// ---------------------------------------------------------------------------

Future<String> _uji01() async {
  final data = await _ambil(_repoNormal());
  _pastikan(data.waktu == _waktuContoh, 'Waktu tidak sesuai: ${data.waktu}');
  _pastikan(data.zonaWaktu == 'Asia/Makassar', 'Zona waktu tidak terbaca.');
  _pastikan(data.latitude == -0.5 && data.longitude == 117.25, 'Koordinat salah.');
  return 'Objek DataKualitasUdara terbentuk dari JSON valid.';
}

RepositoriKualitasUdara _repoNormal() => _repositoriDenganBody(_bodyContoh());

Future<String> _uji02() async {
  final d = await _ambil(_repoNormal());
  _pastikan(d.pm25 == 15.8, 'pm25 salah: ${d.pm25}');
  _pastikan(d.pm10 == 22.4, 'pm10 salah: ${d.pm10}');
  _pastikan(d.usAqi == 58, 'usAqi salah: ${d.usAqi}');
  _pastikan(d.europeanAqi == 41, 'europeanAqi salah: ${d.europeanAqi}');
  _pastikan(d.ozone == 68, 'ozone salah: ${d.ozone}');
  _pastikan(d.nitrogenDioksida == 5.2, 'NO2 salah: ${d.nitrogenDioksida}');
  _pastikan(d.sulfurDioksida == 3.1, 'SO2 salah: ${d.sulfurDioksida}');
  _pastikan(d.karbonMonoksida == 212, 'CO salah: ${d.karbonMonoksida}');
  return 'pm25=15.8, pm10=22.4, usAqi=58, europeanAqi=41 terpetakan benar.';
}

Future<String> _uji03() async {
  final req = await _tangkapRequest();
  final uri = req.url;
  _pastikan(req.method == 'GET', 'Metode bukan GET: ${req.method}');
  _pastikan(uri.scheme == 'https', 'Skema bukan https: ${uri.scheme}');
  _pastikan(uri.host == 'air-quality-api.open-meteo.com', 'Host salah: ${uri.host}');
  _pastikan(uri.path == '/v1/air-quality', 'Path salah: ${uri.path}');
  final lat = double.tryParse(uri.queryParameters['latitude'] ?? '');
  final lon = double.tryParse(uri.queryParameters['longitude'] ?? '');
  _pastikan(lat != null && (lat - _lat).abs() < 1e-6, 'Latitude salah: $lat');
  _pastikan(lon != null && (lon - _lon).abs() < 1e-6, 'Longitude salah: $lon');
  _pastikan(
    req.headers['accept'] == 'application/json',
    'Header Accept tidak terkirim.',
  );
  return 'GET https://air-quality-api.open-meteo.com/v1/air-quality dengan '
      'latitude & longitude benar.';
}

Future<String> _uji04() async {
  final req = await _tangkapRequest();
  final param = req.url.queryParameters['current'];
  _pastikan(param != null, "Parameter 'current' tidak ada.");
  final dikirim = param!.split(',').toSet();
  const diharapkan = <String>{
    'pm2_5',
    'pm10',
    'us_aqi',
    'european_aqi',
    'ozone',
    'nitrogen_dioxide',
    'sulphur_dioxide',
    'carbon_monoxide',
  };
  _pastikan(
    dikirim.length == diharapkan.length && dikirim.containsAll(diharapkan),
    'Isi current tidak sesuai: $param',
  );
  return 'Delapan field polutan/AQI ada pada parameter current.';
}

Future<String> _uji05() async {
  final req = await _tangkapRequest();
  _pastikan(
    req.url.queryParameters['timezone'] == 'auto',
    'timezone bukan auto: ${req.url.queryParameters['timezone']}',
  );
  return 'Query timezone=auto terkirim.';
}

Future<String> _ujiHttpError(int status, http.Response jawaban) async {
  final repo = _buatRepositori((request) async => jawaban);
  final e = await _harapkan<ApiException>(() => _ambil(repo));
  _pastikan(e.statusCode == status, 'statusCode salah: ${e.statusCode}');
  return 'ApiException(statusCode: $status) dilempar.';
}

Future<String> _uji06() => _ujiHttpError(404, http.Response('Not Found', 404));

Future<String> _uji07() => _ujiHttpError(
      500,
      _jawabJson(<String, dynamic>{'error': true, 'reason': 'Galat server'}, status: 500),
    );

Future<String> _uji08() async {
  final repo = _buatRepositori(
    (request) async => http.Response(
      '<html>Ini bukan JSON</html>',
      200,
      headers: const {'content-type': 'text/html; charset=utf-8'},
    ),
  );
  await _harapkan<FormatException>(() => _ambil(repo));
  return 'FormatException dilempar untuk body non-JSON.';
}

Future<String> _uji09() async {
  final kasus = <String, Map<String, dynamic>>{
    "tanpa 'current'": _bodyContoh()..remove('current'),
    "tanpa 'current.time'": _bodyContoh(current: _currentContoh()..remove('time')),
    "tanpa 'latitude'": _bodyContoh()..remove('latitude'),
  };
  for (final entri in kasus.entries) {
    try {
      await _harapkan<FormatException>(() => _ambil(_repositoriDenganBody(entri.value)));
    } on KegagalanPengujian catch (e) {
      throw KegagalanPengujian('Kasus ${entri.key}: ${e.pesan}');
    }
  }
  return 'FormatException dilempar untuk ${kasus.length} kasus field penting hilang.';
}

Future<String> _uji10() async {
  final body = _bodyContoh(
    current: <String, dynamic>{
      'time': _waktuContoh,
      'interval': 900,
      'pm2_5': 12.0,
      'ozone': null, // API dapat mengirim null untuk data yang tidak ada
    },
  );
  final d = await _ambil(_repositoriDenganBody(body));
  _pastikan(d.pm25 == 12.0, 'pm25 seharusnya 12.0, diterima ${d.pm25}');
  _pastikan(d.pm10 == null, 'pm10 seharusnya null.');
  _pastikan(d.usAqi == null, 'usAqi seharusnya null.');
  _pastikan(d.europeanAqi == null, 'europeanAqi seharusnya null.');
  _pastikan(d.ozone == null, 'ozone (null eksplisit) seharusnya null.');
  _pastikan(d.nitrogenDioksida == null, 'NO2 seharusnya null.');
  _pastikan(d.sulfurDioksida == null, 'SO2 seharusnya null.');
  _pastikan(d.karbonMonoksida == null, 'CO seharusnya null.');
  return 'Polutan yang hilang atau bernilai null menjadi null.';
}

Future<String> _uji11() async {
  final kasus = <String, Object>{
    'array JSON': <int>[1, 2, 3],
    'string JSON': 'teks biasa',
    "'current' bukan objek": <String, dynamic>{
      'latitude': -0.5,
      'longitude': 117.25,
      'current': 'bukan objek',
    },
  };
  for (final entri in kasus.entries) {
    try {
      await _harapkan<FormatException>(() => _ambil(_repositoriDenganBody(entri.value)));
    } on KegagalanPengujian catch (e) {
      throw KegagalanPengujian('Kasus ${entri.key}: ${e.pesan}');
    }
  }
  return 'FormatException dilempar untuk ${kasus.length} struktur JSON yang salah.';
}

Future<String> _uji12() async {
  final repo = _buatRepositori(
    (request) async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      return _jawabJson(_bodyContoh());
    },
    batasWaktu: const Duration(milliseconds: 50),
  );
  await _harapkan<TimeoutException>(() => _ambil(repo));
  return 'TimeoutException dilempar saat respons melebihi batas waktu.';
}

Future<String> _uji13() async {
  final body = _bodyContoh(
    current: <String, dynamic>{
      'time': _waktuContoh,
      'pm10': 22, // int
      'pm2_5': 15.5, // double
      'us_aqi': 58, // int
      'european_aqi': 41.5, // double
      'ozone': 68, // int
    },
  );
  final d = await _ambil(_repositoriDenganBody(body));
  _pastikan(d.pm10 == 22.0, 'pm10 int salah: ${d.pm10}');
  _pastikan(d.pm25 == 15.5, 'pm25 double salah: ${d.pm25}');
  _pastikan(d.usAqi == 58.0, 'usAqi int salah: ${d.usAqi}');
  _pastikan(d.europeanAqi == 41.5, 'europeanAqi double salah: ${d.europeanAqi}');
  _pastikan(d.ozone == 68.0, 'ozone int salah: ${d.ozone}');
  return 'Nilai int dan double sama-sama dikonversi menjadi double.';
}

Future<String> _uji14() async {
  final repo = _buatRepositori(
    (request) async => _jawabJson(
      <String, dynamic>{
        'error': true,
        'reason': 'Latitude must be in range of -90 to 90°. Given: 123.0.',
      },
      status: 400,
    ),
  );
  final e = await _harapkan<ApiException>(() => _ambil(repo));
  _pastikan(e.statusCode == 400, 'statusCode salah: ${e.statusCode}');
  _pastikan(e.pesan.contains('Latitude must be'), 'Alasan API tidak terbawa: ${e.pesan}');
  return 'ApiException 400 membawa alasan dari API.';
}

Future<String> _uji15() async {
  final kasus = <String, Object>{
    'string': 'banyak',
    'boolean': true,
  };
  for (final entri in kasus.entries) {
    final body = _bodyContoh(
      current: <String, dynamic>{
        'time': _waktuContoh,
        'pm2_5': entri.value,
      },
    );
    try {
      await _harapkan<FormatException>(() => _ambil(_repositoriDenganBody(body)));
    } on KegagalanPengujian catch (e) {
      throw KegagalanPengujian('Kasus ${entri.key}: ${e.pesan}');
    }
  }
  return 'FormatException dilempar untuk nilai non-numerik.';
}

Future<String> _uji16() async {
  final repo = _buatRepositori(
    (request) async => throw http.ClientException('Koneksi terputus'),
  );
  final e = await _harapkan<JaringanException>(() => _ambil(repo));
  _pastikan(e.pesan.contains('Koneksi terputus'), 'Pesan tidak terbawa: ${e.pesan}');
  return 'ClientException dibungkus menjadi JaringanException.';
}

Future<String> _uji17() async {
  // Satuan CO sengaja diubah untuk membuktikan kode tidak mengasumsikan satuan.
  final body = _bodyContoh();
  (body['current_units'] as Map<String, dynamic>)['carbon_monoxide'] = 'mg/m³';
  final d = await _ambil(_repositoriDenganBody(body));
  _pastikan(d.satuan['pm2_5'] == 'μg/m³', 'Satuan PM2.5 salah: ${d.satuan['pm2_5']}');
  _pastikan(
    d.satuan['carbon_monoxide'] == 'mg/m³',
    'Satuan CO salah: ${d.satuan['carbon_monoxide']}',
  );

  final tanpaUnit = await _ambil(_repositoriDenganBody(_bodyContoh(denganUnit: false)));
  _pastikan(tanpaUnit.satuan.isEmpty, 'Satuan seharusnya kosong.');
  _pastikan(tanpaUnit.pm25 == 15.8, 'Nilai tetap harus terbaca tanpa satuan.');
  return 'Satuan mengikuti current_units; tanpa current_units tidak crash.';
}

// ---------------------------------------------------------------------------
// Penjalan pengujian
// ---------------------------------------------------------------------------

Future<HasilUji> _jalankan(String nama, Future<String> Function() uji) async {
  try {
    final keterangan = await uji();
    return HasilUji(nama: nama, lulus: true, keterangan: keterangan);
  } catch (e) {
    return HasilUji(nama: nama, lulus: false, keterangan: 'Gagal: $e');
  }
}

/// Menjalankan seluruh pengujian MockClient. Tidak ada request internet nyata.
Future<List<HasilUji>> jalankanSemuaPengujian() async {
  final kasus = <String, Future<String> Function()>{
    '01. JSON valid diparsing menjadi DataKualitasUdara': _uji01,
    '02. PM2.5, PM10, dan AQI terpetakan ke properti yang benar': _uji02,
    '03. Latitude dan longitude dikirim lewat query parameter': _uji03,
    '04. Parameter current berisi field yang diperlukan': _uji04,
    '05. Parameter timezone=auto dikirim': _uji05,
    '06. HTTP 404 menghasilkan ApiException': _uji06,
    '07. HTTP 500 menghasilkan ApiException': _uji07,
    '08. Body bukan JSON menghasilkan FormatException': _uji08,
    '09. Field penting hilang menghasilkan FormatException': _uji09,
    '10. Polutan opsional hilang menjadi null': _uji10,
    '11. Struktur JSON salah menghasilkan FormatException': _uji11,
    '12. Respons lambat menghasilkan TimeoutException': _uji12,
    '13. Nilai integer dan desimal diproses dengan benar': _uji13,
    '14. HTTP 400 membawa alasan dari API': _uji14,
    '15. Nilai bukan angka menghasilkan FormatException': _uji15,
    '16. Kegagalan jaringan menghasilkan JaringanException': _uji16,
    '17. Satuan mengikuti current_units dari respons': _uji17,
  };

  final hasil = <HasilUji>[];
  for (final entri in kasus.entries) {
    hasil.add(await _jalankan(entri.key, entri.value));
  }
  return hasil;
}

String ringkasanHasil(List<HasilUji> hasil) {
  final lulus = hasil.where((h) => h.lulus).length;
  return '$lulus dari ${hasil.length} pengujian lulus';
}

void cetakHasil(List<HasilUji> hasil) {
  for (final h in hasil) {
    debugPrint('[${h.lulus ? 'LULUS' : 'GAGAL'}] ${h.nama}');
    debugPrint('        ${h.keterangan}');
  }
  debugPrint('RINGKASAN: ${ringkasanHasil(hasil)}');
}