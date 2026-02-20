import 'package:permission_handler/permission_handler.dart' as handler;

/// Service for handling microphone permission requests and checks.
class PermissionService {
  /// Check current microphone permission status.
  Future<handler.PermissionStatus> checkMicrophonePermission() async {
    return await handler.Permission.microphone.status;
  }

  /// Request microphone permission.
  ///
  /// Returns the permission status after the request.
  Future<handler.PermissionStatus> requestMicrophonePermission() async {
    return await handler.Permission.microphone.request();
  }

  /// Open app settings page for manual permission grant.
  ///
  /// Returns true if settings were opened successfully.
  Future<bool> openAppSettings() async {
    return await handler.openAppSettings();
  }

  /// Check if permission is permanently denied (user selected "Don't ask again").
  ///
  /// On Android, this means the permission is denied and shouldShowRequestRationale is false.
  /// On iOS, permanently denied means the permission is denied.
  Future<bool> isPermanentlyDenied() async {
    final status = await checkMicrophonePermission();
    if (status.isDenied) {
      // On Android, check if we should show rationale
      // If shouldShowRequestRationale is false, permission is permanently denied
      if (await handler.Permission.microphone.shouldShowRequestRationale) {
        return false; // Not permanently denied, can request again
      }
      return true; // Permanently denied
    }
    return false;
  }
}
