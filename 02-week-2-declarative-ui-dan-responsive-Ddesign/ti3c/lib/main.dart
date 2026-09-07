import 'package:flutter/material.dart';
import 'mahasiswa.dart';
import 'lagu.dart';

void main() {
  runApp(const Gunawan());
}

class Gunawan extends StatelessWidget {
  const Gunawan({super.key});

  @override
  Widget build(BuildContext context) {
    final mahasiswa = Mahasiswa(nama: 'Gunawan', nim: 244107020132, kelas: 'TI-3C');
    final lagu = Lagu.currentSong;

    return MaterialApp(
      title: 'Lyric lagu Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 169, 239, 171),
        ),
      ),
      home: Builder(
        builder: (context) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              title: Text('${lagu.penyanyi} - ${lagu.judul}'),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              child: Row(
                children: [
                  Expanded(
                    child: Text(lagu.lyric),
                  ),
                ],
              ),
            ),
            floatingActionButton: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton(
                  onPressed: () {

                  },
                  child: const Icon(Icons.skip_previous),
                ),
                FloatingActionButton(
                  onPressed: () {

                  },
                  child: const Icon(Icons.play_arrow),
                ),
                FloatingActionButton(
                  onPressed: () {

                  },
                  child: const Icon(Icons.pause),
                ),
                FloatingActionButton(
                  onPressed: () {

                  },
                  child: const Icon(Icons.skip_next),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}