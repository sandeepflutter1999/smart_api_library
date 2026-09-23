import 'package:flutter_test/flutter_test.dart';
import 'package:smart_api/smart_api.dart';

void main() {
  group('SmartApiEnvelope.defaultParse', () {
    setUp(() {
      SmartApiConfigKeyMapHolder.keyMap = const SmartApiKeyMap();
    });

    test('reads the default success/message/data keys', () {
      final envelope = SmartApiEnvelope.defaultParse({
        'success': true,
        'message': 'ok',
        'data': {'id': 1},
      });

      expect(envelope.success, isTrue);
      expect(envelope.message, 'ok');
      expect(envelope.data, {'id': 1});
    });

    test('respects a custom SmartApiKeyMap', () {
      SmartApiConfigKeyMapHolder.keyMap = const SmartApiKeyMap(
        successKeys: ['ok'],
        successValues: [true],
        messageKeys: ['msg'],
        dataKeys: ['payload'],
      );

      final envelope = SmartApiEnvelope.defaultParse({
        'ok': true,
        'msg': 'done',
        'payload': [1, 2, 3],
      });

      expect(envelope.success, isTrue);
      expect(envelope.message, 'done');
      expect(envelope.data, [1, 2, 3]);
    });

    test('treats a non-Map body as a failed response', () {
      final envelope = SmartApiEnvelope.defaultParse('plain text error');
      expect(envelope.success, isFalse);
      expect(envelope.message, '');
    });
  });

  group('SmartApiToast.styleForMsgType', () {
    test('maps each SmartApiMsgType to the matching toast style', () {
      expect(SmartApiToast.styleForMsgType(SmartApiMsgType.success), SmartApiToastStyle.success);
      expect(SmartApiToast.styleForMsgType(SmartApiMsgType.error), SmartApiToastStyle.error);
      expect(SmartApiToast.styleForMsgType(SmartApiMsgType.warning), SmartApiToastStyle.warning);
      expect(SmartApiToast.styleForMsgType(SmartApiMsgType.info), SmartApiToastStyle.info);
      expect(SmartApiToast.styleForMsgType(null), SmartApiToastStyle.info);
    });
  });
}
