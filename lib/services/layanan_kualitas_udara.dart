import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Dilempar ketika server mengembalikan status HTTP selain 200.
class ApiException implements Exception {
  const ApiException(this.statusCode, this.pesan);

  final int statusCode;
  final String pesan;

  @override
  String toString() => 'ApiException($statusCode): $pesan';
}

/// Dilempar ketika permintaan gagal karena jaringan (tidak ada koneksi,
/// DNS gagal, koneksi terputus, atau diblokir peramban di Web).
class JaringanException implements Exception {
  const JaringanException(this.pesan);

  final String pesan;

  @override
  String toString() => 'JaringanException: $pesan';
}

/// Lapisan komunikasi jaringan ke Open-Meteo Air Quality API.
class LayananKualitasUdara {
  LayananKualitasUdara({
    required http.Client client,
    this.batasWaktu = const Duration(seconds: 10),
  }) : _client = client;

  static const String host = 'air-quality-api.open-meteo.com';
  static const String path = '/v1/air-quality';

  /// Nama field sesuai dokumentasi Open-Meteo (perhatikan "sulphur").
  static const List<String> variabelCurrent = <String>[
    'pm2_5',
    'pm10',
    'us_aqi',
    'european_aqi',
    'ozone',
    'nitrogen_dioxide',
    'sulphur_dioxide',
    'carbon_monoxide',
  ];

  final http.Client _client;
  final Duration batasWaktu;

  Uri buatUri({required double latitude, required double longitude}) {
    return Uri.https(host, path, <String, String>{
      // 4 desimal (~11 m) sudah jauh lebih rapat daripada grid model (~45 km).
      'latitude': latitude.toStringAsFixed(4),
      'longitude': longitude.toStringAsFixed(4),
      'current': variabelCurrent.join(','),
      'timezone': 'auto',
    });
  }

  /// Mengambil JSON mentah dan memastikan objek terluarnya adalah Map.
  Future<Map<String, dynamic>> ambilJson({
    required double latitude,
    required double longitude,
  }) async {
    final uri = buatUri(latitude: latitude, longitude: longitude);

    http.Response response;
    try {
      response = await _client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(batasWaktu);
    } on TimeoutException {
      throw TimeoutException(
        'Permintaan melebihi batas waktu '
        '${batasWaktu.inMilliseconds / 1000} detik.',
        batasWaktu,
      );
    } on http.ClientException catch (e) {
      throw JaringanException(e.message);
    }

    if (response.statusCode != 200) {
      throw ApiException(response.statusCode, _alasanDariBody(response));
    }

    // Decode byte sebagai UTF-8 agar karakter seperti "μ" dan "³" aman,
    // tanpa bergantung pada header charset.
    final dynamic hasil = jsonDecode(utf8.decode(response.bodyBytes));
    if (hasil is! Map<String, dynamic>) {
      throw FormatException(
        'Struktur JSON tidak sesuai: diharapkan objek, diterima '
        '${hasil.runtimeType}.',
      );
    }
    return hasil;
  }

  /// Mengambil `reason` dari body error Open-Meteo bila ada.
  String _alasanDariBody(http.Response response) {
    try {
      final dynamic isi = jsonDecode(utf8.decode(response.bodyBytes));
      if (isi is Map<String, dynamic> && isi['reason'] is String) {
        return isi['reason'] as String;
      }
    } on FormatException {
      // Body bukan JSON; gunakan pesan bawaan di bawah.
    }
    return 'Server mengembalikan status HTTP ${response.statusCode}.';
  }

  /// Menutup client. Panggil saat layanan tidak dipakai lagi.
  void tutup() => _client.close();
}