import 'package:flutter/material.dart';

import 'models/mahasiswa.dart';
import 'services/api_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Data Mahasiswa - Dio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const MahasiswaListPage(),
    );
  }
}

class MahasiswaListPage extends StatefulWidget {
  const MahasiswaListPage({super.key});

  @override
  State<MahasiswaListPage> createState() => _MahasiswaListPageState();
}

class _MahasiswaListPageState extends State<MahasiswaListPage> {
  final ApiService _apiService = ApiService();
  late Future<List<Mahasiswa>> _mahasiswaFuture;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  void _refreshData() {
    setState(() {
      _mahasiswaFuture = _apiService.getMahasiswa();
    });
  }

  void _showFormDialog({Mahasiswa? mahasiswa}) {
    final isEdit = mahasiswa != null;
    final nimController = TextEditingController(text: mahasiswa?.nim ?? '');
    final namaController = TextEditingController(text: mahasiswa?.nama ?? '');
    final jurusanController = TextEditingController(
      text: mahasiswa?.jurusan ?? '',
    );
    final emailController = TextEditingController(text: mahasiswa?.email ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Ubah Data Mahasiswa' : 'Tambah Mahasiswa'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nimController,
                decoration: const InputDecoration(
                  labelText: 'NIM',
                  hintText: 'Contoh: 21040101',
                ),
              ),
              TextField(
                controller: namaController,
                decoration: const InputDecoration(labelText: 'Nama Lengkap'),
              ),
              TextField(
                controller: jurusanController,
                decoration: const InputDecoration(
                  labelText: 'Program Studi / Jurusan',
                  hintText: 'Contoh: Teknik Informatika',
                ),
              ),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email (Opsional)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              final nim = nimController.text.trim();
              final nama = namaController.text.trim();
              final jurusan = jurusanController.text.trim();
              final email = emailController.text.trim();

              if (nim.isEmpty || nama.isEmpty || jurusan.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('NIM, Nama, dan Jurusan wajib diisi!'),
                  ),
                );
                return;
              }

              final payload = Mahasiswa(
                nim: nim,
                nama: nama,
                jurusan: jurusan,
                email: email.isNotEmpty ? email : null,
              );

              try {
                if (isEdit) {
                  await _apiService.updateMahasiswa(mahasiswa.id!, payload);
                } else {
                  await _apiService.createMahasiswa(payload);
                }
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                if (mounted) {
                  _refreshData();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(e.toString())));
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(Mahasiswa item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content: Text('Yakin ingin menghapus ${item.nama} (${item.nim})?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true && item.id != null) {
      try {
        await _apiService.deleteMahasiswa(item.id!);
        _refreshData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Data Mahasiswa (REST API Dio)'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refreshData(),
        child: FutureBuilder<List<Mahasiswa>>(
          future: _mahasiswaFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_off, color: Colors.red, size: 54),
                      const SizedBox(height: 12),
                      Text(
                        'Gagal memuat data:\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _refreshData,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final list = snapshot.data ?? [];

            if (list.isEmpty) {
              return const Center(
                child: Text(
                  'Belum ada data mahasiswa. Tekan tombol + untuk menambahkan.',
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = list[index];
                return Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        item.nama.isNotEmpty ? item.nama[0].toUpperCase() : '?',
                      ),
                    ),
                    title: Text(
                      item.nama,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'NIM: ${item.nim}\nJurusan: ${item.jurusan}${item.email != null ? '\nEmail: ${item.email}' : ''}',
                    ),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () => _showFormDialog(mahasiswa: item),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _confirmDelete(item),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormDialog(),
        icon: const Icon(Icons.person_add),
        label: const Text('Tambah Mahasiswa'),
      ),
    );
  }
}
