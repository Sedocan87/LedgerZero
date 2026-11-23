import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:play_age_features/play_age_features.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void answer(Future<Object?> Function(MethodCall) handler) =>
      messenger.setMockMethodCallHandler(PlayAgeFeatures.channel, handler);

  setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.android);
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(PlayAgeFeatures.channel, null);
  });

  test('maps MANDATORY_SHARING (1)', () async {
    answer((call) async {
      expect(call.method, 'getApplicableAgeFeatures');
      return [1];
    });
    expect(await PlayAgeFeatures.getApplicableAgeFeatures(), {
      ApplicableAgeFeature.mandatorySharing,
    });
    expect(await PlayAgeFeatures.isMandatorySharing(), isTrue);
  });

  test('an empty set means no mandatory sharing', () async {
    answer((_) async => <int>[]);
    expect(await PlayAgeFeatures.getApplicableAgeFeatures(), isEmpty);
    expect(await PlayAgeFeatures.isMandatorySharing(), isFalse);
  });

  test('ignores feature values it does not know', () async {
    answer((_) async => [1, 42]);
    expect(await PlayAgeFeatures.getApplicableAgeFeatures(), {
      ApplicableAgeFeature.mandatorySharing,
    });
  });

  test("Play's error code reaches Dart as an int", () async {
    answer((_) async => throw PlatformException(code: '-9', message: 'nope'));
    await expectLater(
      PlayAgeFeatures.getApplicableAgeFeatures(),
      throwsA(
        isA<PlayAgeFeaturesException>()
            .having((e) => e.code, 'code', -9)
            .having((e) => e.message, 'message', 'nope'),
      ),
    );
  });

  test('a non-Play failure has no code', () async {
    answer((_) async => throw PlatformException(code: 'UNKNOWN'));
    await expectLater(
      PlayAgeFeatures.getApplicableAgeFeatures(),
      throwsA(
        isA<PlayAgeFeaturesException>().having((e) => e.code, 'code', null),
      ),
    );
  });

  test('never calls the channel off Android', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    var calls = 0;
    answer((_) async {
      calls++;
      return [1];
    });
    expect(await PlayAgeFeatures.isMandatorySharing(), isFalse);
    expect(calls, 0);
  });
}
