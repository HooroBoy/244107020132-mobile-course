import '../../constants.dart';
import '../../repositories/push_messaging.dart';

/// Berlangganan / berhenti berlangganan topik broadcast kampus.
class SetTopicSubscriptionUseCase {
  const SetTopicSubscriptionUseCase(this._push);

  final PushMessaging _push;

  Future<void> call({required bool subscribe}) async {
    if (subscribe) {
      await _push.subscribeTopic(kCampusTopic);
    } else {
      await _push.unsubscribeTopic(kCampusTopic);
    }
  }
}
