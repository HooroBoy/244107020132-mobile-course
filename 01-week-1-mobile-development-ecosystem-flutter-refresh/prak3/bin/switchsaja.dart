import 'package:prak3/prak3.dart' as prak3;
import 'dart:io';

void main(List<String> arguments) {
  String ? name = stdin.readLineSync();
  switch(name) {
    case null:
      print('Nama tidak diketahui');
      break;
    case '':
      print('Nama tidak diketahui');
      break;
    default:
      print('Nama saya adalah $name');
  }
}
