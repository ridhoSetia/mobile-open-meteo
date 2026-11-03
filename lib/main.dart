import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'repositories/repositori_kualitas_udara.dart';
import 'screens/halaman_kualitas_udara.dart';
import 'services/layanan_kualitas_udara.dart';

void main() => runApp(const AplikasiAirQuality());

class AplikasiAirQuality extends StatefulWidget {
  const AplikasiAirQuality({super.key});

  @override
  State<AplikasiAirQuality> createState() => _AplikasiAirQualityState();
}

class _AplikasiAirQualityState extends State<AplikasiAirQuality> {
  late final http.Client _client;
  late final RepositoriKualitasUdara _repositori;

  @override
  void initState() {
    super.initState();
    // Satu client dipakai bersama selama aplikasi berjalan.
    _client = http.Client();
    _repositori = RepositoriKualitasUdara(
      LayananKualitasUdara(client: _client),
    );
  }

  @override
  void dispose() {
    _repositori.tutup(); // menutup http.Client
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Air Quality Monitor',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: HalamanKualitasUdara(repositori: _repositori),
    );
  }
}