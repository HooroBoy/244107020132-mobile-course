import 'package:flutter/material.dart';

import 'mahasiswa.dart';
import 'lagu.dart';

void main() {
  runApp(const GunawanApp());
}

class GunawanApp extends StatelessWidget {
  const GunawanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lyric lagu Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 236, 201, 234),
        ),
      ),
      home: const LyricHomePage(),
    );
  }
}

class LyricHomePage extends StatelessWidget {
  const LyricHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final mahasiswa = Mahasiswa(
      nama: 'Gunawan',
      nim: 244107020132,
      kelas: 'TI-3C',
    );
    final lagu = Lagu.currentSong;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFEBC9EA),
        title: const Text('Lyrica'),
      ),

      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            UserAccountsDrawerHeader(
              decoration: const BoxDecoration(color: Color(0xFFEBC9EA)),
              currentAccountPicture: CircleAvatar(
                backgroundColor: Colors.white,
                child: Text(
                  mahasiswa.nama.isNotEmpty ? mahasiswa.nama[0] : 'G',
                  style: const TextStyle(
                    fontSize: 26.0,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6A1B9A),
                  ),
                ),
              ),
              accountName: Text(
                mahasiswa.nama,
                style: const TextStyle(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
              accountEmail: Text(
                '${mahasiswa.nim} | ${mahasiswa.kelas}',
                style: const TextStyle(color: Colors.black54),
              ),
            ),

            ListTile(
              leading: const Icon(Icons.music_note),
              title: const Text('Layout Widget'),
              subtitle: const Text('Buka halaman layout widget'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LayoutWidgetPage(),
                  ),
                );
              },
            ),

            const Divider(),
          ],
        ),
      ),

      body: PageView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (lagu.coverImagePath != null)
                  Image.asset(
                    lagu.coverImagePath!,
                    height: 180,
                    fit: BoxFit.cover,
                  ),
                const SizedBox(height: 24.0),
                SelectableText(
                  lagu.judul,
                  style: const TextStyle(
                    fontSize: 22.0,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8.0),
                SelectableText(
                  lagu.penyanyi,
                  style: const TextStyle(
                    fontSize: 16.0,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32.0),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Geser untuk melihat lirik',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 13, color: Colors.grey),
                  ],
                ),
              ],
            ),
          ),
          Scrollbar(
            thumbVisibility: true,
            thickness: 6.0,
            radius: const Radius.circular(3.0),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    '~LIRIK~',
                    style: TextStyle(
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16.0),
                  SizedBox(
                    width: double.infinity,
                    child: SelectableText(
                      lagu.lyric,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14.0, height: 1.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

      bottomNavigationBar: Container(
        color: const Color(0xFFEBC9EA),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.skip_previous),
                      color: const Color.fromARGB(255, 0, 0, 0),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(Icons.play_arrow),
                      color: const Color.fromARGB(255, 0, 0, 0),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(Icons.pause),
                      color: const Color.fromARGB(255, 0, 0, 0),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(Icons.skip_next),
                      color: const Color.fromARGB(255, 0, 0, 0),
                      onPressed: () {},
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'Created by: ${mahasiswa.nama} | NIM: ${mahasiswa.nim} | Kelas: ${mahasiswa.kelas}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 12.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class LayoutWidgetPage extends StatelessWidget {
  const LayoutWidgetPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Layout Widget'),
        backgroundColor: const Color(0xFFEBC9EA),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 100,
            child: Container(
              color: const Color.fromARGB(255, 244, 54, 222),
              child: const Center(
                child: Text(
                  'Widget 1',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.red,
              child: const Center(
                child: Text(
                  'Widget 1',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              color: Colors.green,
              child: const Center(
                child: Text(
                  'Widget 2',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ),
          ),
          Flexible(
            child: Container(
              color: Colors.blue,
              child: const Center(
                child: Text(
                  'Widget 3',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ),
          ),
          Stack(
            children: [
              Container(
                color: Colors.yellow,
                height: 100,
                width: double.infinity,
                child: const Center(
                  child: Text(
                    'Widget 4',
                    style: TextStyle(color: Colors.black, fontSize: 18),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  color: Colors.purple,
                  height: 50,
                  width: 50,
                  child: const Center(
                    child: Text(
                      'W5',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
