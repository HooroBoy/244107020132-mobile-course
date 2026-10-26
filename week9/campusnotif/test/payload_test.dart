import 'package:campusnotif/data/masking.dart';
import 'package:campusnotif/messaging/payload.dart';
import 'package:campusnotif/messaging/push_service.dart';
import 'package:campusnotif/routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('routeFromMessage', () {
    test('payload kosong diarahkan ke beranda', () {
      expect(routeFromMessage(<String, dynamic>{}), Routes.home);
      expect(routeFromMessage(<String, dynamic>{'route': ''}), Routes.home);
      expect(routeFromMessage(<String, dynamic>{'route': '   '}), Routes.home);
      expect(routeFromMessage(<String, dynamic>{'route': 123}), Routes.home);
    });

    test('route tanpa garis miring di depan diperbaiki', () {
      expect(
        routeFromMessage(<String, dynamic>{'route': 'pengumuman/3'}),
        '/pengumuman/3',
      );
    });

    test('route dengan garis miring dibiarkan apa adanya', () {
      expect(
        routeFromMessage(<String, dynamic>{'route': '/pengumuman/3'}),
        '/pengumuman/3',
      );
    });

    test('spasi di tepi route dibuang', () {
      expect(
        routeFromMessage(<String, dynamic>{'route': '  /pengumuman/9  '}),
        '/pengumuman/9',
      );
    });
  });

  group('idFromMessage', () {
    test('mengutamakan data.id', () {
      expect(
        idFromMessage(<String, dynamic>{
          'route': '/pengumuman/3',
          'id': '7',
        }),
        '7',
      );
    });

    test('mengambil segmen terakhir route bila id tidak ada', () {
      expect(
        idFromMessage(<String, dynamic>{'route': '/pengumuman/3'}),
        '3',
      );
    });

    test('null bila tidak ada tujuan pengumuman', () {
      expect(idFromMessage(<String, dynamic>{}), isNull);
      expect(idFromMessage(<String, dynamic>{'route': '/'}), isNull);
    });
  });

  group('sanitizeRoute', () {
    test('null / kosong menjadi beranda', () {
      expect(PushService.sanitizeRoute(null), Routes.home);
      expect(PushService.sanitizeRoute(''), Routes.home);
    });

    test('garis miring ditambahkan bila hilang', () {
      expect(
        PushService.sanitizeRoute('pengumuman/3'),
        '/pengumuman/3',
      );
    });
  });

  group('maskSecret', () {
    test('nilai pendek disamarkan seluruhnya', () {
      expect(maskSecret('pendek'), '••••••');
    });

    test('nilai panjang hanya menyisakan 8 awal dan 4 akhir', () {
      const String token = 'abcdefghijklmnopqrstuvwxyz';
      expect(maskSecret(token), 'abcdefgh••••wxyz');
      expect(maskSecret(token), isNot(contains('mnop')));
    });
  });
}
