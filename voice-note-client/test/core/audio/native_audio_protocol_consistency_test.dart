import 'package:flutter_test/flutter_test.dart';
import 'package:suikouji/core/audio/native_audio_event_validator.dart';

class ProtocolMismatch {
  final int index;
  final String message;

  const ProtocolMismatch(this.index, this.message);
}

class NativeAudioProtocolConsistencyChecker {
  static List<ProtocolMismatch> compare({
    required List<Map<Object?, Object?>> androidEvents,
    required List<Map<Object?, Object?>> iosEvents,
  }) {
    final mismatches = <ProtocolMismatch>[];
    if (androidEvents.length != iosEvents.length) {
      mismatches.add(
        ProtocolMismatch(
          -1,
          'Event count mismatch: android=${androidEvents.length}, ios=${iosEvents.length}',
        ),
      );
    }

    final length = androidEvents.length < iosEvents.length
        ? androidEvents.length
        : iosEvents.length;
    for (var i = 0; i < length; i++) {
      final a = androidEvents[i];
      final b = iosEvents[i];

      final validationA = NativeAudioEventValidator.validate(a);
      if (!validationA.valid) {
        mismatches.add(
          ProtocolMismatch(i, 'Android event invalid: ${validationA.message}'),
        );
        continue;
      }
      final validationB = NativeAudioEventValidator.validate(b);
      if (!validationB.valid) {
        mismatches.add(
          ProtocolMismatch(i, 'iOS event invalid: ${validationB.message}'),
        );
        continue;
      }

      final eventA = a['event'];
      final eventB = b['event'];
      if (eventA != eventB) {
        mismatches.add(
          ProtocolMismatch(i, 'Event order mismatch: android=$eventA, ios=$eventB'),
        );
        continue;
      }

      final fieldsA = _collectRequiredFields(a);
      final fieldsB = _collectRequiredFields(b);
      if (fieldsA.length != fieldsB.length ||
          !fieldsA.keys.every(
            (key) => fieldsB.containsKey(key) && fieldsA[key] == fieldsB[key],
          )) {
        mismatches.add(
          ProtocolMismatch(
            i,
            'Field mismatch on "$eventA": android=$fieldsA, ios=$fieldsB',
          ),
        );
      }
    }

    return mismatches;
  }

  static Map<String, String> _collectRequiredFields(Map<Object?, Object?> event) {
    final eventName = event['event'] as String? ?? '';
    final data = (event['data'] as Map<Object?, Object?>?) ?? const <Object?, Object?>{};
    final out = <String, String>{
      'event': eventName,
      'sessionId': '${event['sessionId']}',
    };

    switch (eventName) {
      case 'runtimeInitialized':
        out['focusState'] = '${data['focusState']}';
        out['route'] = '${data['route']}';
        break;
      case 'asrMuteStateChanged':
        out['asrMuted'] = '${data['asrMuted']}';
        break;
      case 'ttsStarted':
        out['ttsPlaying'] = '${data['ttsPlaying']}';
        break;
      case 'ttsCompleted':
      case 'ttsStopped':
        out['ttsPlaying'] = '${data['ttsPlaying']}';
        out['canAutoResume'] = '${data['canAutoResume']}';
        break;
      case 'ttsError':
        out['ttsPlaying'] = '${data['ttsPlaying']}';
        out['canAutoResume'] = '${data['canAutoResume']}';
        final err = event['error'] as Map<Object?, Object?>?;
        out['errorCode'] = '${err?['code']}';
        break;
      case 'bargeInTriggered':
        out['triggerSource'] = '${data['triggerSource']}';
        out['route'] = '${data['route']}';
        out['focusState'] = '${data['focusState']}';
        out['canAutoResume'] = '${data['canAutoResume']}';
        break;
      case 'bargeInCompleted':
        out['success'] = '${data['success']}';
        out['canAutoResume'] = '${data['canAutoResume']}';
        break;
      case 'audioFocusChanged':
        out['focusState'] = '${data['focusState']}';
        out['canAutoResume'] = '${data['canAutoResume']}';
        break;
      case 'audioRouteChanged':
        out['oldRoute'] = '${data['oldRoute']}';
        out['newRoute'] = '${data['newRoute']}';
        out['reason'] = '${data['reason']}';
        break;
      case 'runtimeError':
        final err = event['error'] as Map<Object?, Object?>?;
        out['errorCode'] = '${err?['code']}';
        break;
      default:
        // no-op
        break;
    }

    return out;
  }
}

void main() {
  group('native audio protocol consistency', () {
    test('passes for tts + barge-in scenario', () {
      const android = <Map<Object?, Object?>>[
        {
          'event': 'runtimeInitialized',
          'sessionId': 'sess-1',
          'timestamp': 1,
          'data': {'focusState': 'gain', 'route': 'speaker'},
        },
        {
          'event': 'ttsStarted',
          'sessionId': 'sess-1',
          'requestId': 'req-1',
          'timestamp': 2,
          'data': {'ttsPlaying': true},
        },
        {
          'event': 'bargeInTriggered',
          'sessionId': 'sess-1',
          'timestamp': 3,
          'data': {
            'triggerSource': 'energy_vad',
            'route': 'speaker',
            'focusState': 'gain',
            'canAutoResume': true,
          },
        },
        {
          'event': 'ttsStopped',
          'sessionId': 'sess-1',
          'requestId': 'req-1',
          'timestamp': 4,
          'data': {'ttsPlaying': false, 'canAutoResume': true},
        },
        {
          'event': 'bargeInCompleted',
          'sessionId': 'sess-1',
          'timestamp': 5,
          'data': {'success': true, 'canAutoResume': true},
        },
      ];

      const ios = <Map<Object?, Object?>>[
        {
          'event': 'runtimeInitialized',
          'sessionId': 'sess-1',
          'timestamp': 11,
          'data': {'focusState': 'gain', 'route': 'speaker'},
        },
        {
          'event': 'ttsStarted',
          'sessionId': 'sess-1',
          'requestId': 'req-1',
          'timestamp': 12,
          'data': {'ttsPlaying': true},
        },
        {
          'event': 'bargeInTriggered',
          'sessionId': 'sess-1',
          'timestamp': 13,
          'data': {
            'triggerSource': 'energy_vad',
            'route': 'speaker',
            'focusState': 'gain',
            'canAutoResume': true,
          },
        },
        {
          'event': 'ttsStopped',
          'sessionId': 'sess-1',
          'requestId': 'req-1',
          'timestamp': 14,
          'data': {'ttsPlaying': false, 'canAutoResume': true},
        },
        {
          'event': 'bargeInCompleted',
          'sessionId': 'sess-1',
          'timestamp': 15,
          'data': {'success': true, 'canAutoResume': true},
        },
      ];

      final mismatches = NativeAudioProtocolConsistencyChecker.compare(
        androidEvents: android,
        iosEvents: ios,
      );
      expect(mismatches, isEmpty);
    });

    test('fails when event order differs', () {
      const android = <Map<Object?, Object?>>[
        {
          'event': 'audioFocusChanged',
          'sessionId': 'sess-2',
          'timestamp': 1,
          'data': {'focusState': 'loss_transient', 'canAutoResume': false},
        },
        {
          'event': 'audioRouteChanged',
          'sessionId': 'sess-2',
          'timestamp': 2,
          'data': {
            'oldRoute': 'speaker',
            'newRoute': 'bluetooth',
            'reason': 'new_device_available',
          },
        },
      ];

      const ios = <Map<Object?, Object?>>[
        {
          'event': 'audioRouteChanged',
          'sessionId': 'sess-2',
          'timestamp': 10,
          'data': {
            'oldRoute': 'speaker',
            'newRoute': 'bluetooth',
            'reason': 'new_device_available',
          },
        },
        {
          'event': 'audioFocusChanged',
          'sessionId': 'sess-2',
          'timestamp': 11,
          'data': {'focusState': 'loss_transient', 'canAutoResume': false},
        },
      ];

      final mismatches = NativeAudioProtocolConsistencyChecker.compare(
        androidEvents: android,
        iosEvents: ios,
      );
      expect(mismatches, isNotEmpty);
      expect(mismatches.first.message, contains('Event order mismatch'));
    });
  });
}
