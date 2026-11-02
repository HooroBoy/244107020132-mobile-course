/// Pendaftaran token perangkat ke backend agar server bisa mengirim notifikasi
/// personal ke pengguna ini.
///
/// Nama platform tidak menjadi parameter: implementasi di lapisan data yang tahu
/// cara membaca platform, sehingga lapisan domain tetap bebas dari API Flutter.
abstract interface class DeviceRepository {
  /// `true` bila backend menerima token.
  ///
  /// Kegagalan jaringan tidak boleh mematikan aplikasi: token tetap tersimpan di
  /// sisi Firebase, hanya laporan ke backend yang tertunda.
  Future<bool> register({required String token});

  /// Melepas token saat logout agar pengguna tidak lagi menerima notifikasi
  /// personal di perangkat yang sudah keluar.
  Future<bool> unregister({required String token});
}
