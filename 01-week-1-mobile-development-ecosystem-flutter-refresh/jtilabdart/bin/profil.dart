import 'package:jtilabdart/jtilabdart.dart' as jtilabdart;
import 'dart:io';
void main(List<String> arguments) {
  String? nama = "";
  String? nim = "";
  String? email = "";

  print("Masukkan Nama Anda: ");
  nama = stdin.readLineSync();
  print("Masukkan NIM Anda: ");
  nim = stdin.readLineSync();
  print("Masukkan Email Anda: ");
  email = stdin.readLineSync();
  print("--------------------------");
  if (nama == null || nim == null || email == null||nama == "" || nim == "" || email == "") {
    print("Input tidak valid. Pastikan semua data diisi.");
    }else {
    print("Nama: $nama");
    print("NIM: $nim");
    print("Email: $email");
    }
}