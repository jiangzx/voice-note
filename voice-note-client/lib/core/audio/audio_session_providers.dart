import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio_session_service.dart';

final audioSessionServiceProvider = Provider<AudioSessionService>((ref) {
  return AudioSessionService();
});
