class Mahasiswa {
  final int? id;
  final String nim;
  final String nama;
  final String jurusan;
  final String? email;

  Mahasiswa({
    this.id,
    required this.nim,
    required this.nama,
    required this.jurusan,
    this.email,
  });

  factory Mahasiswa.fromJson(Map<String, dynamic> json) {
    return Mahasiswa(
      id: json['id'] as int?,
      nim: json['nim'] as String,
      nama: json['nama'] as String,
      jurusan: json['jurusan'] as String,
      email: json['email'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nim': nim,
      'nama': nama,
      'jurusan': jurusan,
      'email': email,
    };
  }
}