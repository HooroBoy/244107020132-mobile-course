import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Profil Mahasiswa'),
          backgroundColor: Colors.blueAccent,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min, 
            children: [
              Icon(Icons.account_circle, size: 100, color: Colors.blueAccent),
              SizedBox(height: 16),
              Text(
                'Gunawan Wibisono',
                style: TextStyle(
                  fontSize: 26, 
                  fontWeight: FontWeight.bold
                )
              ),
              SizedBox(height: 8),
              Text(
                'NIM: 244107020132',
                style: TextStyle(
                  fontSize: 18, 
                  color: Colors.black87
                )
              ),
              SizedBox(height: 4),
              Text(
                'Program Studi: Teknik Informatika',
                style: TextStyle(
                  fontSize: 18, 
                  color: Colors.black54
                )
              ),
              SizedBox(height: 24),
              Text(
                'Pemrograman Mobile — Minggu 1',
                style: TextStyle(
                  fontSize: 16, 
                  fontStyle: FontStyle.italic,
                  color: Colors.grey
                )
              ),
            ]
          ),
        ),
      ),
    );
  }
}