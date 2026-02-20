import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'native_audio_gateway.dart';

final nativeAudioGatewayProvider = Provider<NativeAudioGateway>((ref) {
  return NativeAudioGateway();
});
