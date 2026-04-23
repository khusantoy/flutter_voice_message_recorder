import 'package:permission_handler/permission_handler.dart';

enum MicPermissionResult { granted, denied, permanentlyDenied }

class RecorderPermission {
  Future<MicPermissionResult> ensureMicPermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) return MicPermissionResult.granted;
    if (status.isPermanentlyDenied) return MicPermissionResult.permanentlyDenied;

    final result = await Permission.microphone.request();
    if (result.isGranted) return MicPermissionResult.granted;
    if (result.isPermanentlyDenied) return MicPermissionResult.permanentlyDenied;
    return MicPermissionResult.denied;
  }

  Future<void> openSettings() => openAppSettings();
}
