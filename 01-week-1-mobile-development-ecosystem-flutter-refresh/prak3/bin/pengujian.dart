import 'package:prak3/prak3.dart' as prak3;
import 'dart:io';

void main(List<String> arguments) {
  print('Masukkan nama Anda: ');
  String ? name = stdin.readLineSync();
  if(name != null && name.isNotEmpty) {
    print('Nama anda adalah $name');
  } else {
    print('Nama tidak diketahui');
  }

  String status = (name != null && name.isNotEmpty) ? 'Nama anda adalah $name' : 'Nama tidak diketahui';
  print(status);
}
