import 'package:prak2/prak2.dart' as prak2;
late int a;
void main(List<String> arguments) {
  int a = 10;
  double b = 3.14;
  String c = 'Hello, Dart!';
  bool d = true;
  print('Integer: $a');
  print('Double: $b');
  print('String: $c');
  print('Boolean: $d');
  String e = '12';
  int f = a+int.parse(e);
  print('Hasil penjumlahan: $f');
  List<String> names = ['Alice', 'Bob', 'Charlie'];
  List<int> numbers = [1, 2, 3, 4, 5];
  print('Names: $names');
  print('First name: ${names[0]}');
  print('Numbers: $numbers');
  print('Numbers length: ${numbers.length}');
  Map<String, int> ages = {'Alice': 25, 'Bob': 30, 'Charlie': 35};
  print('Ages: ${ages['Alice']}');
  dynamic g = 'Hello';
  print('Dynamic: $g');
  g = 42;
  print('Dynamic: $g');
}