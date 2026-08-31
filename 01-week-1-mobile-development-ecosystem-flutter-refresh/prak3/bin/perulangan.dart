import 'package:prak3/prak3.dart' as prak3;
import 'dart:io';

void main(List<String> arguments) {
  int i = 0;
  // while(i < 5) {
  //   print('Perulangan ke-${i+1}');
  //   i++;
  // }
  // do {
  //   print('Perulangan ke-${i+1}');
  //   i++;
  // } while(i == 5);
  // for(i = 10; i >= 1; i--) {
  //   print('Perulangan ke-${i}');
  // }
  for(;;) {
      if(i == 5) {
        break;
      }
      print('Perulangan');
      i++;
  }
  for(int j = 1; j <= 5; j++) {
    if(j == 3) {
      continue;
    }
    print('Perulangan ke-${j}');
  }
}
