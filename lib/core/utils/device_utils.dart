import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceUtils {
  static const String _deviceUuidKey = 'device_uuid';

  static Future<String> getDeviceUuid() async {
    final prefs = await SharedPreferences.getInstance();
    String? uuid = prefs.getString(_deviceUuidKey);

    if (uuid != null) {
      return uuid;
    }

    final deviceInfo = DeviceInfoPlugin();

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        uuid = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        uuid = iosInfo.identifierForVendor;
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        uuid = linuxInfo.machineId;
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        uuid = windowsInfo.deviceId;
      } else if (Platform.isMacOS) {
        // macOS specific handling if needed, or fallback
      }
    } catch (e) {
      // Fallback if platform info fails
    }

    if (uuid == null || uuid.isEmpty) {
      uuid = const Uuid().v4();
    }

    await prefs.setString(_deviceUuidKey, uuid);
    return uuid;
  }
}
