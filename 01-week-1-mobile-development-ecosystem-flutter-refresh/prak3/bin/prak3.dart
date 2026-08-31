import 'package:prak3/prak3.dart' as prak3;
import 'dart:io';

void main(List<String> arguments) {
  // print('Hello world: ${prak3.calculate()}!');
  // String? name;
  // name = 'Gunawan';
  // print('Nama saya adalah ${name ?? 'Nama tidak diketahui'}');
  print('Masukkan nama Anda: ');
  String ? name = stdin.readLineSync();
  print('Nama saya adalah ${name==null || name.isEmpty ? 'Nama tidak diketahui' : name}');
}
