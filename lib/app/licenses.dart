import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

bool _registered = false;

/// Adds the licences of what the app bundles outside of its Dart packages
/// to the licence page (Settings > About > Open-source licences). The
/// packages' own LICENSE files are collected by the Flutter build.
///
/// * the Roboto font files in `assets/fonts/` (PDF reports);
/// * zxing-cpp and its bundled copy of libzint, which the QR scanner
///   package (flutter_zxing) compiles into its native library; the package's
///   own LICENSE file covers only its Dart and glue code.
///
/// Safe to call more than once.
void registerBundledLicenses() {
  if (_registered) {
    return;
  }
  _registered = true;
  LicenseRegistry.addLicense(_bundledLicenses);
}

/// The Roboto licence file is the unchanged text of the Apache License 2.0,
/// which is also the licence of zxing-cpp.
const String _apacheLicenseAsset = 'assets/fonts/LICENSE-Roboto.txt';

Stream<LicenseEntry> _bundledLicenses() async* {
  final apache = await rootBundle.loadString(_apacheLicenseAsset);
  yield LicenseEntryWithLineBreaks(const ['Roboto'], apache);
  yield LicenseEntryWithLineBreaks(const [
    'zxing-cpp',
  ], '$_zxingCppNotice\n\n$apache');
  yield const LicenseEntryWithLineBreaks(['zint'], _zintLicense);
}

const String _zxingCppNotice =
    'zxing-cpp (https://github.com/zxing-cpp/zxing-cpp)\n'
    'Copyright ZXing authors, Nu-book Inc., Huy Cuong Nguyen, '
    'Axel Waggershauser and contributors.\n'
    'Licensed under the Apache License, Version 2.0.';

const String _zintLicense = '''
libzint - the open source barcode library
Copyright (C) 2008-2025 Robin Stuart <rstuart114@gmail.com>

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
3. Neither the name of the project nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.''';

/// Lets a test register the licences again after it reset the registry.
@visibleForTesting
void resetBundledLicensesForTesting() => _registered = false;
