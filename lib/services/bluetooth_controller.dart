import 'dart:async';
import 'dart:math';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:get/get.dart';

class DeviceMetrics {
  final String deviceId;

  int rssi;
  double smoothedRssi;

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
  }

  Duration get timeSinceLastSeen => DateTime.now().difference(lastSeen);
}

class BluetoothController extends GetxController {
  final RxList<ScanResult> scanResults = <ScanResult>[].obs;
  final RxList<String> scannedStudentUUIDs = <String>[].obs;

  // ✅ Logging toggle
  final RxBool isLoggingEnabled = false.obs;

  // ✅ Store log lines for one scan session
  final List<String> _currentSessionLogs = [];

  // ✅ NEW: Metrics storage
  final Map<String, DeviceMetrics> deviceMetrics = {};

  final Set<String> _loggedDeviceIds = {};

  StreamSubscription<List<ScanResult>>? _scanSubscription;

  // ✅ NEW: Track scan start time for latency
  DateTime? _scanStartTime;

  String? _currentSessionFileName;

  Future<void> requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothScan,
      Permission.location,
    ].request();
  }

  Future<void> _saveLogToFile(
    DateTime scanStartTime,
    DateTime scanEndTime,
  ) async {
    try {
      final downloadsDir = await getDownloadsDirectory();

      if (downloadsDir == null) {
        print("Unable to access Downloads directory.");
        return;
      }

      if (_currentSessionFileName == null) {
        print("No session file name found.");
        return;
      }

      final file = File("${downloadsDir.path}/$_currentSessionFileName");

      const header =
          "Timestamp,DeviceID,RSSI,AverageRSSI,MinRSSI,MaxRSSI,SmoothedRSSI,Latency(ms),TxPower,Connectable,ServiceUUID\n";

      final buffer = StringBuffer();
      buffer.write(header);

      for (final line in _currentSessionLogs) {
        buffer.writeln(line);
      }

      buffer.writeln();
      buffer.writeln("scan_duration: [$scanStartTime] - [$scanEndTime]");

      await file.writeAsString(buffer.toString());

      print("✅ CSV log saved at: ${file.path}");
    } catch (e) {
      print("❌ Error saving CSV file: $e");
    }
  }

  void scanDevices(List<Guid> guidList) async {
    scanResults.clear();
    deviceMetrics.clear();
    _loggedDeviceIds.clear(); // ✅ Reset per scan session

    FlutterBluePlus.stopScan();

    _scanStartTime = DateTime.now();

    _currentSessionFileName =
        "smarttendance_${DateTime.now().microsecondsSinceEpoch}.csv";

    // ✅ If logging enabled, start fresh session
    if (isLoggingEnabled.value) {
      _currentSessionLogs.clear();
    }

    FlutterBluePlus.startScan(
      withServices: guidList,
      timeout: Duration(seconds: 5),
    );

    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      scanResults.assignAll(results);

      scannedStudentUUIDs.assignAll(
        convertUUIDsToStrings(
          results.map((r) => r.advertisementData.serviceUuids).toList(),
        ),
      );

      for (var result in results) {
        final id = result.device.remoteId.toString();

        // 🚫 Skip if we've already processed this device
        if (_loggedDeviceIds.contains(id)) {
          continue;
        }

        // Mark device as logged
        _loggedDeviceIds.add(id);

        if (!deviceMetrics.containsKey(id)) {
          deviceMetrics[id] = DeviceMetrics(
            deviceId: id,
            rssi: result.rssi,
            advertisementData: result.advertisementData,
            scanStartTime: _scanStartTime,
          );
        } else {
          deviceMetrics[id]!.update(result.rssi, result.advertisementData);
        }

        // ✅ Logging per device update
        if (isLoggingEnabled.value) {
          final metrics = deviceMetrics[id]!;

          final serviceUuid = metrics.advertisementData.serviceUuids.isNotEmpty
              ? metrics.advertisementData.serviceUuids.first.toString()
              : "";

          final line = [
            DateTime.now().toIso8601String(),
            id,
            metrics.rssi,
            metrics.averageRssi.toStringAsFixed(2),
            metrics.minRssi,
            metrics.maxRssi,
            metrics.smoothedRssi.toStringAsFixed(2),
            metrics.latencyMs ?? "",
            metrics.advertisementData.txPowerLevel ?? "",
            metrics.advertisementData.connectable,
            serviceUuid,
          ].join(",");

          _currentSessionLogs.add(line);
        }
      }

      update();
    });

    Future.delayed(Duration(seconds: 5), () async {
      if (isLoggingEnabled.value && _scanStartTime != null) {
        final scanEndTime = DateTime.now();
        await _saveLogToFile(_scanStartTime!, scanEndTime);
      }
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
