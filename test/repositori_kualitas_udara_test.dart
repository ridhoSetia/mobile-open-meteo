import 'package:air_quality_monitor/tests/pengujian_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('seluruh pengujian MockClient lulus', () async {
    final hasil = await jalankanSemuaPengujian();
    cetakHasil(hasil);

    expect(hasil, isNotEmpty);
    for (final h in hasil) {
      expect(h.lulus, isTrue, reason: '${h.nama} -> ${h.keterangan}');
    }
  });
}