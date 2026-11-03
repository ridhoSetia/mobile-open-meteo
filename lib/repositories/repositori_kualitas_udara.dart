import '../models/data_kualitas_udara.dart';
import '../services/layanan_kualitas_udara.dart';

/// Menghubungkan layanan jaringan dengan model; tidak berisi kode UI.
class RepositoriKualitasUdara {
  RepositoriKualitasUdara(this._layanan);

  final LayananKualitasUdara _layanan;

  Future<DataKualitasUdara> ambilDataKualitasUdara({
    required double latitude,
    required double longitude,
  }) async {
    if (latitude < -90 || latitude > 90) {
      throw ArgumentError.value(latitude, 'latitude', 'Harus -90 sampai 90.');
    }
    if (longitude < -180 || longitude > 180) {
      throw ArgumentError.value(
        longitude,
        'longitude',
        'Harus -180 sampai 180.',
      );
    }

    final json = await _layanan.ambilJson(
      latitude: latitude,
      longitude: longitude,
    );
    return DataKualitasUdara.fromJson(json);
  }

  void tutup() => _layanan.tutup();
}