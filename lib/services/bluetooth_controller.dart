import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:get/get.dart';

class BluetoothController extends GetxController {
  final RxList<ScanResult> scanResults = <ScanResult>[].obs;
  final RxList<String> scannedStudentUUIDs = <String>[].obs;

  StreamSubscription<List<ScanResult>>? _scanSubscription;

  Future<void> requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothScan,
      Permission.location,
    ].request();
  }

  void scanDevices(List<Guid> guidList) {
    scanResults.clear();

    FlutterBluePlus.stopScan();

    FlutterBluePlus.startScan(
      withServices: guidList,
      timeout: Duration(seconds: 5),
    );

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      scanResults.assignAll(results);

      scannedStudentUUIDs.assignAll(
        convertUUIDsToStrings(
          results
              .map((result) => result.advertisementData.serviceUuids)
              .toList(),
        ),
      );

      update();
    });
  }

  List<String> convertUUIDsToStrings(List<List<Guid>> uuidLists) {
    return uuidLists
        .expand((uuidList) => uuidList)
        .map((uuid) => uuid.toString())
        .toList();
  }

  List<String> getStoredUUIDs() {
    return scannedStudentUUIDs.toList();
  }

  @override
  void onClose() {
    _scanSubscription?.cancel();
    FlutterBluePlus.stopScan();
    super.onClose();
  }
}
