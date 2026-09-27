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
              leading: const Icon(Icons.view_compact),
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

            ListTile(
              leading: const Icon(Icons.text_fields),
              title: const Text('Teks dan Icon'),
              subtitle: const Text('Buka halaman teks dan icon'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TeksIconPage()),
                );
              },
            ),

            ListTile(
              leading: const Icon(Icons.smart_button),
              title: const Text('Button Widget'),
              subtitle: const Text('Buka halaman button widget'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ButtonWidgetPage(),
                  ),
                );
              },
            ),

            ListTile(
              leading: const Icon(Icons.input),
              title: const Text('Input Widget'),
              subtitle: const Text('Buka halaman input widget'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const InputWidgetPage(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Image Widget'),
              subtitle: const Text('Buka halaman image widget'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ImageWidgetPage(),
                  ),
                );
              },
            ),
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

class TeksIconPage extends StatelessWidget {
  const TeksIconPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teks dan Icon'),
        backgroundColor: const Color(0xFFEBC9EA),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Ini adalah teks contoh',
              style: TextStyle(fontSize: 20),
            ),
            RichText(
              text: TextSpan(
                text: 'Ini adalah teks dengan ',
                style: TextStyle(color: Colors.black, fontSize: 16),
                children: <TextSpan>[
                  TextSpan(
                    text: 'beberapa gaya',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  TextSpan(text: ' dan '),
                  TextSpan(
                    text: 'warna berbeda',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
            ),
            const ImageIcon(AssetImage('assets/cover.png'), size: 100),
            const SizedBox(height: 20),
            const Icon(Icons.favorite, color: Colors.red, size: 50),
            const SelectableText(
              'Ini adalah teks yang dapat diseleksi',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class ButtonWidgetPage extends StatelessWidget {
  const ButtonWidgetPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Button Widget'),
        backgroundColor: const Color(0xFFEBC9EA),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {},
              child: const Text('Elevated Button'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {},
              child: const Text('Outlined Button'),
            ),
            const SizedBox(height: 10),
            TextButton(onPressed: () {}, child: const Text('Text Button')),
            const SizedBox(height: 10),
            IconButton(onPressed: () {}, icon: const Icon(Icons.thumb_up)),
            const SizedBox(height: 10),
            FloatingActionButton(
              onPressed: () {},
              child: const Icon(Icons.add),
            ),
            const SizedBox(height: 10),
            PopupMenuButton<String>(
              onSelected: (value) {},
              itemBuilder: (BuildContext context) {
                return {'Option 1', 'Option 2', 'Option 3'}.map((
                  String choice,
                ) {
                  return PopupMenuItem<String>(
                    value: choice,
                    child: Text(choice),
                  );
                }).toList();
              },
            ),
            const SizedBox(height: 10),
            DropdownButton<String>(
              value: 'Option 1',
              onChanged: (String? newValue) {},
              items: <String>['Option 1', 'Option 2', 'Option 3']
                  .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  })
                  .toList(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
    );
  }
}

class InputWidgetPage extends StatelessWidget {
  const InputWidgetPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Input Widget'),
        backgroundColor: const Color(0xFFEBC9EA),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Masukkan teks',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Masukkan teks dengan validasi',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              CheckboxListTile(
                title: const Text('Centang saya'),
                value: true,
                onChanged: (bool? value) {},
              ),
              const SizedBox(height: 10),
              RadioListTile<int>(
                title: const Text('Pilihan 1'),
                value: 1,
                groupValue: 1,
                onChanged: (int? value) {},
              ),
              RadioListTile<int>(
                title: const Text('Pilihan 2'),
                value: 2,
                groupValue: 1,
                onChanged: (int? value) {},
              ),
              SwitchListTile(
                title: const Text('Aktifkan saya'),
                value: true,
                onChanged: (bool? value) {},
              ),
              Slider(
                value: 50,
                min: 0,
                max: 100,
                divisions: 10,
                label: '50',
                onChanged: (double value) {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ImageWidgetPage extends StatelessWidget {
  const ImageWidgetPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Widget'),
        backgroundColor: const Color(0xFFEBC9EA),
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/cover.png', width: 200),
              const SizedBox(height: 20),
              CircleAvatar(
                radius: 100,
                backgroundImage: NetworkImage(
                  'https://images.pexels.com/photos/3761513/pexels-photo-3761513.jpeg',
                ),
              ),
              const SizedBox(height: 20),
              Card(
                elevation: 4.0,
                shape: RoundedRectangleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    "contoh widget card.",
                    style: TextStyle(fontSize: 18.0),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
