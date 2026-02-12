import 'dart:async';
import 'dart:math';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:get/get.dart';

class DeviceMetrics {
  final String deviceId;

  int rssi;
  double smoothedRssi;
  double? estimatedDistance;

  int minRssi;
  int maxRssi;
  int totalReadings;
  double averageRssi;

  DateTime firstSeen;
  DateTime lastSeen;

  // ✅ NEW: Latency from scan start
  int? latencyMs;

  AdvertisementData advertisementData;

  DeviceMetrics({
    required this.deviceId,
    required this.rssi,
    required this.advertisementData,
    DateTime? scanStartTime, // Optional scan start
  })  : smoothedRssi = rssi.toDouble(),
        minRssi = rssi,
        maxRssi = rssi,
        totalReadings = 1,
        averageRssi = rssi.toDouble(),
        firstSeen = DateTime.now(),
        lastSeen = DateTime.now() {
    if (scanStartTime != null) {
      latencyMs = DateTime.now().difference(scanStartTime).inMilliseconds;
    }
  }

  void update(int newRssi, AdvertisementData newAdv) {
    rssi = newRssi;

    // Exponential Moving Average for RSSI smoothing
    smoothedRssi = (0.7 * smoothedRssi) + (0.3 * newRssi);

    minRssi = min(minRssi, newRssi);
    maxRssi = max(maxRssi, newRssi);

    totalReadings++;
    averageRssi =
        ((averageRssi * (totalReadings - 1)) + newRssi) / totalReadings;

    lastSeen = DateTime.now();
    advertisementData = newAdv;

    estimatedDistance =
        _estimateDistance(smoothedRssi, advertisementData.txPowerLevel);
  }

  double? _estimateDistance(double rssi, int? txPower) {
    if (txPower == null) return null;

    double ratio = rssi / txPower;

    if (ratio < 1.0) {
      return pow(ratio, 10).toDouble();
    } else {
      return (0.89976 * pow(ratio, 7.7095) + 0.111).toDouble();
    }
  }

  Duration get timeSinceLastSeen => DateTime.now().difference(lastSeen);
}

class BluetoothController extends GetxController {
  final RxList<ScanResult> scanResults = <ScanResult>[].obs;
  final RxList<String> scannedStudentUUIDs = <String>[].obs;

  // ✅ NEW: Metrics storage
  final Map<String, DeviceMetrics> deviceMetrics = {};

  StreamSubscription<List<ScanResult>>? _scanSubscription;

  // ✅ NEW: Track scan start time for latency
  DateTime? _scanStartTime;

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
    deviceMetrics.clear();

    FlutterBluePlus.stopScan();

    _scanStartTime = DateTime.now(); // ✅ record scan start

    FlutterBluePlus.startScan(
      withServices: guidList,
      timeout: Duration(seconds: 5),
    );

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      // 🔹 EXISTING LOGIC
      scanResults.assignAll(results);

      scannedStudentUUIDs.assignAll(
        convertUUIDsToStrings(
          results.map((r) => r.advertisementData.serviceUuids).toList(),
        ),
      );

      // ✅ NEW: Collect metrics per device with latency
      for (var result in results) {
        final id = result.device.remoteId.toString();

        if (!deviceMetrics.containsKey(id)) {
          deviceMetrics[id] = DeviceMetrics(
            deviceId: id,
            rssi: result.rssi,
            advertisementData: result.advertisementData,
            scanStartTime: _scanStartTime, // Pass start time
          );
        } else {
          deviceMetrics[id]!.update(result.rssi, result.advertisementData);
        }
      }

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

  Map<String, DeviceMetrics> getAllMetrics() {
    return deviceMetrics;
  }

  DeviceMetrics? getMetricsForDevice(String deviceId) {
    return deviceMetrics[deviceId];
  }

  @override
  void onClose() {
    _scanSubscription?.cancel();
    FlutterBluePlus.stopScan();
    super.onClose();
  }
}
