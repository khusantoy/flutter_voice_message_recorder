import 'package:permission_handler/permission_handler.dart' as ph;

import '../application/ports.dart';

class PermissionHandlerMic implements MicPermissionPort {
  @override
  Future<MicPermissionResult> ensureMicPermission() async {
    final status = await ph.Permission.microphone.status;
    if (status.isGranted) return MicPermissionResult.granted;
    if (status.isPermanentlyDenied) {
      return MicPermissionResult.permanentlyDenied;
    }

    final result = await ph.Permission.microphone.request();
    if (result.isGranted) return MicPermissionResult.granted;
    if (result.isPermanentlyDenied) {
      return MicPermissionResult.permanentlyDenied;
    }
    return MicPermissionResult.denied;
  }

  @override
  Future<void> openSettings() => ph.openAppSettings();
}
