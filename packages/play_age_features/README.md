# play_age_features

A small local Flutter plugin (Android only). It asks Google Play whether mandatory age-signal sharing applies to the current user. It wraps `getApplicableAgeFeatures()` from `com.google.android.play:age-signals:0.0.6`.

```dart
import 'package:play_age_features/play_age_features.dart';

final mandatory = await PlayAgeFeatures.isMandatorySharing(); // false off Android
```

- A Play failure throws `PlayAgeFeaturesException`. Its `code` is Play's `AgeSignalsErrorCode`; for example, -9 is `APP_NOT_OWNED`.
- This is a stopgap until `age_range_signals` supports the method.
- For why it exists, how the apps use it, and how to remove it later, see [../AGE_SIGNALS_CALIFORNIA.md](../AGE_SIGNALS_CALIFORNIA.md).
