import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smarttendance/pages/login_page.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:smarttendance/services/bluetooth_controller.dart';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';

class StudentHomePage extends StatefulWidget {
  const StudentHomePage({super.key});

  @override
  StudentHomePageState createState() => StudentHomePageState();
}

class StudentHomePageState extends State<StudentHomePage> {
  final user = FirebaseAuth.instance.currentUser;
  final FlutterBlePeripheral blePeripheral = FlutterBlePeripheral();
  final bluetoothController = Get.put(BluetoothController());
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  List<Map<String, dynamic>> studentCourses = [];

  final uuid = Uuid();
  bool _isSupported = false;
  bool _isAdvertising = false;
  late String uniqueUuid;
  late AdvertiseData advertiseData;

  @override
  void initState() {
    super.initState();
    _initPlatformState();
    _fetchStudentCourses();

    bluetoothController.requestPermissions();

    String studentId = user?.uid ?? "default_student";
    uniqueUuid = generateStudentUUID(studentId);

    advertiseData = AdvertiseData(
      serviceUuid: uniqueUuid,
      localName: 'Student_Device',
      manufacturerId: 1234,
      manufacturerData: Uint8List.fromList([1, 2, 3, 4, 5, 6]),
      includePowerLevel: true,
    );
  }

  String generateStudentUUID(String studentId) {
    return uuid.v5(Uuid.NAMESPACE_OID, studentId);
  }

  void _refreshPage() async {
    await _initPlatformState();
    await _fetchStudentCourses();
  }

  Future<void> _initPlatformState() async {
    final bool isSupported = await blePeripheral.isSupported;
    final bool isAdvertising = await blePeripheral.isAdvertising;

    setState(() {
      _isSupported = isSupported;
      if (isAdvertising) {
        blePeripheral.stop();
        _isAdvertising = false;
      }
    });
  }

  Future<void> _toggleAdvertise() async {
    if (await blePeripheral.isAdvertising) {
      await blePeripheral.stop();
      setState(() => _isAdvertising = false);
      _showMessage("BLE advertising stopped.");
    } else {
      await FlutterBluePlus.turnOn();
      await blePeripheral.start(
          advertiseData: advertiseData, advertiseSettings: advertiseSettings);
      setState(() => _isAdvertising = true);
      _showMessage("BLE advertising started.");
    }
  }

  void _showMessage(String message) {
    _messengerKey.currentState?.showSnackBar(SnackBar(content: Text(message)));
  }

  void _signUserOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  Future<void> _fetchStudentCourses() async {
    if (user == null) return;

    final QuerySnapshot coursesSnapshot =
        await FirebaseFirestore.instance.collection('Courses').get();

    List<Map<String, dynamic>> enrolledCourses = [];

    for (var courseDoc in coursesSnapshot.docs) {
      Map<String, dynamic> courseData =
          courseDoc.data() as Map<String, dynamic>;
      List<dynamic> attendanceList = courseData['Attendance'] ?? [];

      for (var studentEntry in attendanceList) {
        if (studentEntry['Student'] == user!.uid) {
          enrolledCourses.add({
            'name': courseData['Name'],
            'lectures': courseData['Lectures'],
            'attendance': studentEntry['Attendances'],
          });
          break;
        }
      }
    }

    setState(() {
      studentCourses = enrolledCourses;
    });
  }

  final AdvertiseSettings advertiseSettings = AdvertiseSettings(
    advertiseMode: AdvertiseMode.advertiseModeLowLatency,
    connectable: true,
    timeout: 0,
    txPowerLevel: AdvertiseTxPower.advertiseTxPowerHigh,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _messengerKey,
      appBar: AppBar(
        title: const Text(
          "Participant Home",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blueGrey.shade900,
        actions: [
          IconButton(
            onPressed: _refreshPage,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
          IconButton(
            onPressed: _signUserOut,
            icon: const Icon(Icons.logout, color: Colors.white),
          )
        ],
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.blueGrey.shade900,
              Colors.blueGrey.shade600,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Card(
                  color: Colors.blueGrey.shade400,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  elevation: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        const Text(
                          "LOGGED IN AS PARTICIPANT!",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "WELCOME ${user?.email ?? 'Unknown'}",
                          style: const TextStyle(
                            fontSize: 18,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          "Your Unique UUID:",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SelectableText(
                          uniqueUuid,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.lightBlueAccent,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Your Sessions:",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                studentCourses.isEmpty
                    ? const Text(
                        "No sessions found",
                        style: TextStyle(fontSize: 16, color: Colors.white70),
                      )
                    : SizedBox(
                        height: 300,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: studentCourses.length,
                          itemBuilder: (context, index) {
                            final course = studentCourses[index];
                            return Card(
                              color: Colors.blueGrey.shade300,
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 10),
                              child: ListTile(
                                title: Text(
                                  course['name'],
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                subtitle: Text(
                                  "Attendances: ${course['attendance']} / ${course['lectures']}",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.white70,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                const SizedBox(height: 20),
                Text(
                  _isSupported ? "BLE Supported ✅" : "BLE Not Supported ❌",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _toggleAdvertise,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isAdvertising
                        ? Colors.redAccent
                        : Colors.green.shade600,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: const Size(175, 50),
                  ),
                  child: Text(
                    _isAdvertising ? "Stop Advertising" : "Start Advertising",
                    style: const TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
