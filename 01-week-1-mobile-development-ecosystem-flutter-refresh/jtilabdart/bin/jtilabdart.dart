import 'package:jtilabdart/jtilabdart.dart' as jtilabdart;
import 'dart:io';
void main(List<String> arguments) {
  // print('Hello world: ${jtilabdart.calculate()}!');
  double panjang = 10.0;
  double lebar = 5.0;
  double luas = jtilabdart.hitungLuasPersegiPanjang(panjang, lebar);
  print('Luas persegi panjang dengan panjang $panjang dan lebar $lebar adalah $luas');

  
}
