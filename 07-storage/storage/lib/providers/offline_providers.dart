import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Saklar offline deterministik untuk demonstrasi dan pengujian.
final forceOfflineProvider = NotifierProvider<ForceOfflineNotifier, bool>(
  ForceOfflineNotifier.new,
);

class ForceOfflineNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setOffline(bool value) => state = value;

  void toggle() => state = !state;
}
