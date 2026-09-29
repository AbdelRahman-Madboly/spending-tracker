import 'package:spending_tracker/features/capture/permission_prompt.dart';

/// A permission service driven by the test: [current] is what the system
/// says, [afterRequest] what it says once the dialog is answered.
class FakePermissionService implements PermissionService {
  FakePermissionService(this.current, {this.afterRequest, this.throws = false});

  AppPermissionStatus current;
  AppPermissionStatus? afterRequest;
  bool throws;
  final requested = <AppPermission>[];
  int settingsOpened = 0;

  @override
  Future<AppPermissionStatus> status(AppPermission permission) async {
    if (throws) throw Exception('no plugin');
    return current;
  }

  @override
  Future<AppPermissionStatus> request(AppPermission permission) async {
    requested.add(permission);
    current = afterRequest ?? current;
    return current;
  }

  @override
  Future<bool> openSettings() async {
    settingsOpened++;
    return true;
  }
}
