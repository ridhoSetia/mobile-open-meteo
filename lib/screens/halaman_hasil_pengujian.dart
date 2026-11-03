import 'package:flutter/material.dart';

import '../tests/pengujian_repository.dart';

class HalamanHasilPengujian extends StatefulWidget {
  const HalamanHasilPengujian({super.key});

  @override
  State<HalamanHasilPengujian> createState() => _HalamanHasilPengujianState();
}

class _HalamanHasilPengujianState extends State<HalamanHasilPengujian> {
  late Future<List<HasilUji>> _hasil;

  @override
  void initState() {
    super.initState();
    _hasil = jalankanSemuaPengujian();
  }

  void _ulangi() {
    setState(() {
      _hasil = jalankanSemuaPengujian();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hasil Pengujian MockClient'),
        actions: [
          IconButton(
            tooltip: 'Jalankan ulang',
            icon: const Icon(Icons.refresh),
            onPressed: _ulangi,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: FutureBuilder<List<HasilUji>>(
              future: _hasil,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final hasil = snapshot.data ?? const <HasilUji>[];
                final semuaLulus = hasil.isNotEmpty && hasil.every((h) => h.lulus);
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      color: semuaLulus ? Colors.green.shade100 : Colors.red.shade100,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          ringkasanHasil(hasil),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ),
                    for (final h in hasil)
                      Card(
                        child: ListTile(
                          leading: Icon(
                            h.lulus ? Icons.check_circle : Icons.cancel,
                            color: h.lulus ? Colors.green : Colors.red,
                          ),
                          title: Text(h.nama),
                          subtitle: Text(h.keterangan),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}