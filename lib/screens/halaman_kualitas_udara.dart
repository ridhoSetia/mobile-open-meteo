import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../models/data_kualitas_udara.dart';
import '../repositories/repositori_kualitas_udara.dart';
import '../services/layanan_kualitas_udara.dart';
import 'halaman_hasil_pengujian.dart';

// ---------------------------------------------------------------------------
// Kategori US AQI
// ---------------------------------------------------------------------------

class KategoriAqi {
  const KategoriAqi(this.label, this.warna, this.keterangan);

  final String label;
  final Color warna;
  final String keterangan;
}

/// Kategori hanya untuk US AQI. Jangan dipakai untuk European AQI.
/// Nilai di atas 500 (mungkin menurut dokumentasi) tetap "Berbahaya".
KategoriAqi? kategoriUsAqi(double? aqi) {
  if (aqi == null || aqi.isNaN || aqi < 0) return null;
  final n = aqi.round();
  if (n <= 50) {
    return const KategoriAqi('Baik', Color(0xFF2E7D32),
        'Kualitas udara memuaskan; risiko dari polusi udara kecil atau tidak ada.');
  } else if (n <= 100) {
    return const KategoriAqi('Sedang', Color(0xFFF9A825),
        'Kualitas udara dapat diterima; sebagian kecil orang yang sangat sensitif mungkin terpengaruh.');
  } else if (n <= 150) {
    return const KategoriAqi('Tidak sehat bagi kelompok sensitif', Color(0xFFEF6C00),
        'Kelompok sensitif (anak-anak, lansia, penderita gangguan pernapasan atau jantung) sebaiknya mengurangi aktivitas berat di luar ruangan.');
  } else if (n <= 200) {
    return const KategoriAqi('Tidak sehat', Color(0xFFC62828),
        'Semua orang mulai dapat merasakan dampak kesehatan; kelompok sensitif berisiko lebih serius.');
  } else if (n <= 300) {
    return const KategoriAqi('Sangat tidak sehat', Color(0xFF6A1B9A),
        'Peringatan kesehatan: risiko meningkat bagi semua orang.');
  }
  return const KategoriAqi('Berbahaya', Color(0xFF7E0023),
      'Kondisi darurat kesehatan: seluruh penduduk kemungkinan terdampak.');
}

// ---------------------------------------------------------------------------
// Halaman utama
// ---------------------------------------------------------------------------

class HalamanKualitasUdara extends StatefulWidget {
  const HalamanKualitasUdara({super.key, required this.repositori});

  final RepositoriKualitasUdara repositori;

  @override
  State<HalamanKualitasUdara> createState() => _HalamanKualitasUdaraState();
}

class _HalamanKualitasUdaraState extends State<HalamanKualitasUdara> {
  // Koordinat awal Samarinda sebagai contoh, bukan lokasi GPS pengguna.
  static const double _latAwal = -0.5022;
  static const double _lonAwal = 117.1536;

  final _kunciForm = GlobalKey<FormState>();
  final _kontrolLat = TextEditingController(text: '$_latAwal');
  final _kontrolLon = TextEditingController(text: '$_lonAwal');

  // Future disimpan di state agar rebuild tidak memicu request baru.
  Future<DataKualitasUdara>? _masaDepan;
  double? _latTerakhir;
  double? _lonTerakhir;

  @override
  void initState() {
    super.initState();
    _muat(_latAwal, _lonAwal);
  }

  @override
  void dispose() {
    _kontrolLat.dispose();
    _kontrolLon.dispose();
    super.dispose();
  }

  void _muat(double lat, double lon) {
    _latTerakhir = lat;
    _lonTerakhir = lon;
    _masaDepan = widget.repositori.ambilDataKualitasUdara(
      latitude: lat,
      longitude: lon,
    );
  }

  void _cari() {
    if (!(_kunciForm.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    final lat = _parseKoordinat(_kontrolLat.text)!;
    final lon = _parseKoordinat(_kontrolLon.text)!;
    setState(() => _muat(lat, lon));
  }

  void _muatUlang() {
    final lat = _latTerakhir;
    final lon = _lonTerakhir;
    if (lat == null || lon == null) return;
    setState(() => _muat(lat, lon));
  }

  void _bukaHalamanPengujian() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const HalamanHasilPengujian()),
    );
  }

  static double? _parseKoordinat(String? teks) {
    if (teks == null) return null;
    final nilai = double.tryParse(teks.trim().replaceAll(',', '.'));
    if (nilai == null || nilai.isNaN || nilai.isInfinite) return null;
    return nilai;
  }

  String? _validasiLatitude(String? teks) {
    if (teks == null || teks.trim().isEmpty) return 'Latitude tidak boleh kosong';
    final n = _parseKoordinat(teks);
    if (n == null) return 'Masukkan angka yang valid';
    if (n < -90 || n > 90) return 'Latitude harus antara -90 dan 90';
    return null;
  }

  String? _validasiLongitude(String? teks) {
    if (teks == null || teks.trim().isEmpty) return 'Longitude tidak boleh kosong';
    final n = _parseKoordinat(teks);
    if (n == null) return 'Masukkan angka yang valid';
    if (n < -180 || n > 180) return 'Longitude harus antara -180 dan 180';
    return null;
  }

  String _pesanError(Object error) {
    if (error is ApiException) {
      if (error.statusCode == 400) {
        return 'Permintaan ditolak server (HTTP 400): ${error.pesan}';
      }
      if (error.statusCode >= 500) {
        return 'Server Open-Meteo sedang bermasalah (HTTP ${error.statusCode}). '
            'Coba lagi beberapa saat lagi.';
      }
      return 'Server mengembalikan HTTP ${error.statusCode}: ${error.pesan}';
    }
    if (error is TimeoutException) {
      return 'Permintaan melebihi batas waktu. Periksa koneksi internet lalu coba lagi.';
    }
    if (error is JaringanException) {
      final petunjukWeb = kIsWeb
          ? ' Di Web, permintaan juga dapat diblokir kebijakan CORS peramban.'
          : '';
      return 'Tidak dapat terhubung ke server. Periksa koneksi internet.'
          '$petunjukWeb (Detail: ${error.pesan})';
    }
    if (error is FormatException) {
      return 'Data dari server tidak sesuai format yang diharapkan: ${error.message}';
    }
    return 'Terjadi kesalahan tak terduga: $error';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.air),
            SizedBox(width: 8),
            Text('Air Quality Monitor'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Perbarui data',
            icon: const Icon(Icons.refresh),
            onPressed: _muatUlang,
          ),
          IconButton(
            tooltip: 'Hasil pengujian MockClient',
            icon: const Icon(Icons.fact_check_outlined),
            onPressed: _bukaHalamanPengujian,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _bangunFormulir(),
                const SizedBox(height: 16),
                FutureBuilder<DataKualitasUdara>(
                  future: _masaDepan,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const _KeadaanMemuat();
                    }
                    if (snapshot.hasError) {
                      return _KartuError(
                        pesan: _pesanError(snapshot.error!),
                        onCobaLagi: _muatUlang,
                      );
                    }
                    final data = snapshot.data;
                    if (data == null) {
                      return _KartuError(
                        pesan: 'Tidak ada data yang diterima.',
                        onCobaLagi: _muatUlang,
                      );
                    }
                    return _KontenData(data: data, onRefresh: _muatUlang);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bangunFormulir() {
    final angka = const TextInputType.numberWithOptions(signed: true, decimal: true);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _kunciForm,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Lokasi (koordinat)', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              const Text(
                'Nilai awal adalah koordinat Samarinda sebagai contoh, '
                'bukan lokasi GPS Anda.',
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _kontrolLat,
                      keyboardType: angka,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Latitude',
                        border: OutlineInputBorder(),
                      ),
                      validator: _validasiLatitude,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _kontrolLon,
                      keyboardType: angka,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _cari(),
                      decoration: const InputDecoration(
                        labelText: 'Longitude',
                        border: OutlineInputBorder(),
                      ),
                      validator: _validasiLongitude,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _cari,
                  icon: const Icon(Icons.search),
                  label: const Text('Cari Kualitas Udara'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Widget penyusun
// ---------------------------------------------------------------------------

class _KeadaanMemuat extends StatelessWidget {
  const _KeadaanMemuat();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Mengambil data kualitas udara...'),
        ],
      ),
    );
  }
}

class _KartuError extends StatelessWidget {
  const _KartuError({required this.pesan, required this.onCobaLagi});

  final String pesan;
  final VoidCallback onCobaLagi;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 8),
            Text(
              'Gagal memuat data',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(pesan, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCobaLagi,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

class _KontenData extends StatelessWidget {
  const _KontenData({required this.data, required this.onRefresh});

  final DataKualitasUdara data;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    String? satuan(String kunciApi) => data.satuan[kunciApi];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _KartuRingkasan(data: data, onRefresh: onRefresh),
        const SizedBox(height: 8),
        _KartuEuropeanAqi(nilai: data.europeanAqi),
        _KartuPolutan(
          nama: 'PM2.5',
          ikon: Icons.grain,
          nilai: data.pm25,
          satuan: satuan('pm2_5'),
        ),
        _KartuPolutan(
          nama: 'PM10',
          ikon: Icons.blur_on,
          nilai: data.pm10,
          satuan: satuan('pm10'),
        ),
        _KartuPolutan(
          nama: 'Ozon (O₃)',
          ikon: Icons.wb_sunny_outlined,
          nilai: data.ozone,
          satuan: satuan('ozone'),
        ),
        _KartuPolutan(
          nama: 'Nitrogen dioksida (NO₂)',
          ikon: Icons.directions_car_outlined,
          nilai: data.nitrogenDioksida,
          satuan: satuan('nitrogen_dioxide'),
        ),
        _KartuPolutan(
          nama: 'Sulfur dioksida (SO₂)',
          ikon: Icons.factory_outlined,
          nilai: data.sulfurDioksida,
          satuan: satuan('sulphur_dioxide'),
        ),
        _KartuPolutan(
          nama: 'Karbon monoksida (CO)',
          ikon: Icons.local_fire_department_outlined,
          nilai: data.karbonMonoksida,
          satuan: satuan('carbon_monoxide'),
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Sumber: Open-Meteo Air Quality API. Data berasal dari model '
            'atmosfer CAMS (Copernicus Atmosphere Monitoring Service), bukan '
            'pembacaan langsung sensor di lokasi. Di luar Eropa, resolusi '
            'model global sekitar 45 km.',
            style: TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _KartuRingkasan extends StatelessWidget {
  const _KartuRingkasan({required this.data, required this.onRefresh});

  final DataKualitasUdara data;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final kategori = kategoriUsAqi(data.usAqi);
    final latar = kategori?.warna ?? Colors.grey.shade400;
    final teksWarna = ThemeData.estimateBrightnessForColor(latar) == Brightness.dark
        ? Colors.white
        : Colors.black87;
    final tema = Theme.of(context).textTheme;
    final zona = data.zonaWaktu == null ? '' : ' (${data.zonaWaktu})';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Titik grid model: ${data.latitude.toStringAsFixed(2)}, '
                    '${data.longitude.toStringAsFixed(2)}',
                    style: tema.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: latar,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Text('US AQI', style: tema.titleMedium?.copyWith(color: teksWarna)),
                  Text(
                    data.usAqi == null ? '–' : '${data.usAqi!.round()}',
                    style: tema.displayMedium?.copyWith(
                      color: teksWarna,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    kategori?.label ?? 'Data tidak tersedia',
                    textAlign: TextAlign.center,
                    style: tema.titleLarge?.copyWith(color: teksWarna),
                  ),
                ],
              ),
            ),
            if (kategori != null) ...[
              const SizedBox(height: 8),
              Text(kategori.keterangan),
            ],
            const SizedBox(height: 8),
            Text('Waktu data: ${data.waktu.replaceFirst('T', ' ')}$zona'),
            const SizedBox(height: 4),
            const Text(
              'Sumber: Open-Meteo (data berbasis model atmosfer, bukan sensor langsung).',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Perbarui Data'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KartuEuropeanAqi extends StatelessWidget {
  const _KartuEuropeanAqi({required this.nilai});

  final double? nilai;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.public)),
        title: const Text('European AQI'),
        subtitle: Text(
          nilai == null
              ? 'Data tidak tersedia'
              : '${nilai!.round()}  (skala Eropa, berbeda dari US AQI)',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _KartuPolutan extends StatelessWidget {
  const _KartuPolutan({
    required this.nama,
    required this.ikon,
    required this.nilai,
    required this.satuan,
  });

  final String nama;
  final IconData ikon;
  final double? nilai;
  final String? satuan;

  @override
  Widget build(BuildContext context) {
    final String teks;
    if (nilai == null) {
      teks = 'Data tidak tersedia';
    } else {
      teks = '${nilai!.toStringAsFixed(1)} ${satuan ?? ''}'.trim();
    }
    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Icon(ikon)),
        title: Text(nama),
        subtitle: Text(
          teks,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}