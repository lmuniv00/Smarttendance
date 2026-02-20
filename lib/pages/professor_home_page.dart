import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:smarttendance/components/button.dart';
import 'package:smarttendance/pages/login_page.dart';
import 'package:smarttendance/services/firestore.dart';
import 'package:smarttendance/services/bluetooth_controller.dart';
import 'package:get/get.dart';

class ProfessorHomePage extends StatefulWidget {
  const ProfessorHomePage({super.key});

  @override
  State<ProfessorHomePage> createState() => _ProfessorHomePageState();
}

class _ProfessorHomePageState extends State<ProfessorHomePage> {
  final user = FirebaseAuth.instance.currentUser;
  final FirestoreService firestoreService = FirestoreService();
  List<Map<String, dynamic>> professorCourses = [];
  String? _selectedCourse;
  int scanCountdown = 5; // Timer countdown
  Timer? _scanTimer;

  List<String> storedUUIDs = [];

  void startScanWithCountdown() {
    final controller = Get.find<BluetoothController>();

    setState(() {
      scanCountdown = 5; // Reset countdown
    });

    // Start scanning
    controller.scanDevices(guidList);

    // Start countdown timer
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (scanCountdown > 0) {
        setState(() {
          scanCountdown--;
        });
      } else {
        timer.cancel();
        setState(() {
          scanCountdown = 5; // Reset countdown after scan finishes
        });
        storedUUIDs = controller.getStoredUUIDs();
        print("DEBUG: Stored UUIDs -> $storedUUIDs");
        _showScanCompleteDialog();
      }
    });
  }

  void _refreshPage() async {
    await fetchProfessorCourses();
  }

  Future<void> _updateStudentAttendance() async {
    try {
      // Validate selected course
      if (_selectedCourse == null) {
        print("Error: No course selected.");
        return;
      }

      // Get the currently logged-in professor's email
      String? professorEmail = user?.email;
      if (professorEmail == null) {
        print("Error: No logged-in professor.");
        return;
      }

      // Fetch the professor's document using their email
      QuerySnapshot professorQuery = await FirebaseFirestore.instance
          .collection('Professors')
          .where('Email', isEqualTo: professorEmail)
          .limit(1)
          .get();

      if (professorQuery.docs.isEmpty) {
        print("Professor document not found.");
        return;
      }

      // Get professor's assigned courses
      var professorDoc = professorQuery.docs.first;
      List<dynamic> courseRefs = professorDoc['Courses'] ?? [];

      // Find the selected course reference
      DocumentReference? selectedCourseRef;
      for (var courseRef in courseRefs) {
        if (courseRef is DocumentReference && courseRef.id == _selectedCourse) {
          selectedCourseRef = courseRef;
          break;
        }
      }

      if (selectedCourseRef == null) {
        print(
            "Error: Selected course not found in professor's assigned courses.");
        return;
      }

      // Get the stored UUIDs of students who were present
      List<String> presentUUIDs = storedUUIDs;

      // Fetch the selected course document
      DocumentSnapshot courseDoc = await selectedCourseRef.get();
      if (!courseDoc.exists) {
        print("Error: Selected course document not found.");
        return;
      }

      // Get the attendance array
      List<dynamic> attendanceList = List.from(courseDoc['Attendance'] ?? []);

      // Iterate through the attendance list and update students' attendance
      for (var attendance in attendanceList) {
        if (attendance is Map<String, dynamic> &&
            presentUUIDs.contains(attendance['StudentUUID'])) {
          attendance['Attendances'] = (attendance['Attendances'] ?? 0) + 1;
        }
      }

      // Update Firestore with the modified attendance list
      await selectedCourseRef.update({'Attendance': attendanceList});

      print("Attendance updated successfully for $_selectedCourse!");
    } catch (e) {
      print("Error updating attendance: $e");
    }
  }

  void _showScanCompleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Scan Complete"),
        content: const Text(
            "The scan has finished. Do you want to update students' attendance?"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
              _incrementLectureCount();
              _updateStudentAttendance();
            },
            child: const Text("Yes"),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close the dialog
            },
            child: const Text("No"),
          ),
        ],
      ),
    );
  }

  Future<void> _incrementLectureCount() async {
    try {
      if (user?.email == null) {
        print("ERROR: No logged-in user or email missing.");
        return;
      }

      print("DEBUG: Fetching professor document for email: ${user!.email}");

      // Query Firestore to find professor document by email
      QuerySnapshot professorQuery = await FirebaseFirestore.instance
          .collection('Professors')
          .where('Email', isEqualTo: user!.email) // Match email with Firestore
          .limit(1) // There should be only one matching professor
          .get();

      if (professorQuery.docs.isEmpty) {
        print("ERROR: Professor document not found for email: ${user!.email}");
        return;
      }

      // Get the first (and only) professor document
      DocumentSnapshot userDoc = professorQuery.docs.first;

      print("DEBUG: Professor document found -> ID: ${userDoc.id}");

      // ✅ FIX: Explicitly cast userDoc.data() to a Map
      Map<String, dynamic>? userData = userDoc.data() as Map<String, dynamic>?;

      if (userData == null) {
        print("ERROR: User data is null.");
        return;
      }

      List courseRefs = userData['Courses'] ?? [];
      print("DEBUG: Courses found: $courseRefs");

      // Find the selected course reference
      DocumentReference? selectedCourseRef;
      for (var courseRef in courseRefs) {
        if (courseRef is DocumentReference && courseRef.id == _selectedCourse) {
          selectedCourseRef = courseRef;
          break;
        }
      }

      if (selectedCourseRef != null) {
        print(
            "DEBUG: Updating lecture count for course ${selectedCourseRef.id}");

        await selectedCourseRef.update({
          'Lectures': FieldValue.increment(1),
        });

        print("SUCCESS: Lecture count updated.");
      } else {
        print("ERROR: Selected course not found in professor's courses.");
      }
    } catch (e) {
      print("EXCEPTION: Error updating lecture count: $e");
    }
  }

  List<Guid> get guidList =>
      getStudentUUIDsForSelectedCourse().map((uuid) => Guid(uuid)).toList();

  void _signUserOut() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    Get.put(BluetoothController());
    fetchProfessorCourses();
  }

  List<String> getStudentUUIDsForSelectedCourse() {
    if (_selectedCourse == null) return [];

    // Find the selected course
    var selectedCourse = professorCourses.firstWhere(
      (course) => course['code'] == _selectedCourse,
    );

    // Extract student UUIDs
    return selectedCourse['students']
        .map<String>((student) => student['uuid'].toString()) // Extract 'uuid'
        .toList();
  }

  Future<void> fetchProfessorCourses() async {
    if (user == null) return;

    try {
      // Fetch the professor's document
      QuerySnapshot professorSnapshot = await FirebaseFirestore.instance
          .collection('Professors')
          .where('Email', isEqualTo: user!.email)
          .get();

      if (professorSnapshot.docs.isNotEmpty) {
        var professorData = professorSnapshot.docs.first;
        List<DocumentReference> courseRefs =
            List<DocumentReference>.from(professorData['Courses'] ?? []);

        if (courseRefs.isEmpty) {
          setState(() {
            professorCourses = [];
            _selectedCourse = null;
          });
          return;
        }

        // Fetch all courses asynchronously
        List<Map<String, dynamic>> courses = [];
        List<Future<void>> fetchTasks = [];

        for (var courseRef in courseRefs) {
          fetchTasks.add(
            courseRef.get().then((courseDoc) async {
              if (courseDoc.exists) {
                List<Map<String, dynamic>> students =
                    await fetchStudentsForCourse(courseRef);
                courses.add({
                  'name': courseDoc['Name'] ?? 'Unnamed Course',
                  'code': courseDoc.id,
                  'students': students,
                });
              }
            }),
          );
        }

        // Wait for all Firestore requests to complete
        await Future.wait(fetchTasks);

        // Update state after fetching all courses
        setState(() {
          professorCourses = courses;
          _selectedCourse = professorCourses.isNotEmpty
              ? professorCourses.first['code']
              : null;
        });

        List<String> studentUUIDs = getStudentUUIDsForSelectedCourse();
        List<Guid> guidList = studentUUIDs.map((uuid) => Guid(uuid)).toList();

        print(guidList);
      }
    } catch (e) {
      print("Error fetching professor courses: $e");
    }
  }

  Future<List<Map<String, dynamic>>> fetchStudentsForCourse(
      DocumentReference courseRef) async {
    List<Map<String, dynamic>> students = [];

    try {
      // Fetch students enrolled in this course
      QuerySnapshot studentSnapshot = await FirebaseFirestore.instance
          .collection('Students')
          .where('Courses', arrayContains: courseRef)
          .get();

      // Fetch attendance data for the course
      DocumentSnapshot courseDoc = await courseRef.get();
      if (!courseDoc.exists) return students; // Exit if course doesn't exist

      Map<String, dynamic> courseData =
          courseDoc.data() as Map<String, dynamic>? ?? {};
      List<dynamic> attendanceList =
          List<dynamic>.from(courseData['Attendance'] ?? []);
      int totalLectures = courseData['Lectures'] ?? 0;

      for (var studentDoc in studentSnapshot.docs) {
        String studentUUID = studentDoc['UUID'] ?? '';

        // Find attendance record for this student
        var studentAttendanceEntry = attendanceList.firstWhere(
          (entry) =>
              entry['StudentUUID'] == studentUUID, // Ensure correct field name
          orElse: () => null, // Return null if no record found
        );

        students.add({
          'name': studentDoc['Name'] ?? 'Unknown',
          'surname': studentDoc['Surname'] ?? '',
          'uuid': studentUUID,
          'lectures': totalLectures, // Total lectures in the course
          'attendance': (studentAttendanceEntry != null)
              ? (studentAttendanceEntry['Attendances'] ??
                  0) // Correct default value
              : 0, // Default to 0 if no record found
        });
      }
    } catch (e) {
      print("Error fetching students for course: $e");
    }

    return students;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Coordinator Home",
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
              Colors.blueGrey.shade400,
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
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 5,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        const Text(
                          "LOGGED IN AS COORDINATOR!",
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
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                const Text(
                  "Your Sessions:",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                professorCourses.isEmpty
                    ? const Center(
                        child: Text(
                          "No sessions found.",
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: professorCourses.length,
                        itemBuilder: (context, index) {
                          final course = professorCourses[index];
                          return Card(
                            color: Colors.blueGrey.shade300,
                            margin: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            child: ExpansionTile(
                              title: Text(
                                course['name'],
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              subtitle: Text(
                                "Session Code: ${course['code']}",
                                style: const TextStyle(color: Colors.white70),
                              ),
                              trailing: Column(
                                mainAxisSize:
                                    MainAxisSize.min, // Ensures compact layout
                                children: [
                                  Radio<String>(
                                    value: course['code'],
                                    groupValue: _selectedCourse,
                                    onChanged: (String? value) {
                                      setState(() {
                                        _selectedCourse = value;
                                        print(
                                            getStudentUUIDsForSelectedCourse());
                                      });
                                    },
                                    activeColor: Colors.white,
                                  ),
                                ],
                              ),
                              children: course['students'].isEmpty
                                  ? [
                                      const Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Text(
                                          "No participants enrolled.",
                                          style:
                                              TextStyle(color: Colors.white70),
                                        ),
                                      )
                                    ]
                                  : course['students'].map<Widget>((student) {
                                      // Ensure values are properly extracted
                                      int totalLectures =
                                          student['lectures'] is int
                                              ? student['lectures']
                                              : 0;
                                      int attendedLectures =
                                          student['attendance'];

                                      return ListTile(
                                        title: Text(
                                          "${student['name']} ${student['surname']}",
                                          style: const TextStyle(
                                              color: Colors.white),
                                        ),
                                        subtitle: Text(
                                          "Attendance: $attendedLectures / $totalLectures",
                                          style: const TextStyle(
                                              color: Colors.white70),
                                        ),
                                      );
                                    }).toList(),
                            ),
                          );
                        },
                      ),
                const SizedBox(height: 30),
                // ✅ Logging Toggle Card
                GetBuilder<BluetoothController>(
                  builder: (controller) {
                    return Card(
                      color: Colors.blueGrey.shade400,
                      elevation: 5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 15),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Enable Scan Logging",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Obx(() => Switch(
                                  value: controller.isLoggingEnabled.value,
                                  activeColor: Colors.greenAccent,
                                  onChanged: (value) {
                                    controller.isLoggingEnabled.value = value;

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          value
                                              ? "Logging ENABLED"
                                              : "Logging DISABLED",
                                        ),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                )),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                GetBuilder<BluetoothController>(
                  builder: (controller) {
                    return Column(
                      children: [
                        MyButton(
                          onTap: startScanWithCountdown,
                          text: scanCountdown > 0
                              ? 'Start scan' // Show countdown
                              : 'Scanning',
                          startColor: Colors.green,
                          endColor: Colors.lightGreenAccent,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          scanCountdown > 0
                              ? "Scanning ends in: $scanCountdown sec"
                              : "Scan complete!",
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 30),
                        const Text(
                          "Connected Participants",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Obx(() {
                          if (controller.scanResults.isEmpty) {
                            return const Center(
                              child: Text(
                                "No devices found.",
                                style: TextStyle(color: Colors.white70),
                              ),
                            );
                          }
                          return ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: controller.scanResults.length,
                            itemBuilder: (context, index) {
                              final data = controller.scanResults[index];
                              final metrics = controller.getMetricsForDevice(
                                data.device.remoteId.toString(),
                              );
                              return Card(
                                color: Colors.blueGrey.shade300,
                                elevation: 3,
                                margin: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                child: ListTile(
                                  title: Text(
                                    data.advertisementData.advName.isNotEmpty
                                        ? data.advertisementData.advName
                                        : "Unknown Device",
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "MAC: ${data.device.remoteId}",
                                        style: const TextStyle(
                                            color: Colors.white70),
                                      ),
                                      Text(
                                        "UUID: ${data.advertisementData.serviceUuids.isNotEmpty ? data.advertisementData.serviceUuids.first : "No UUID"}",
                                        style: const TextStyle(
                                            color: Colors.white70),
                                      ),
                                      if (metrics != null) ...[
                                        const SizedBox(height: 6),
                                        Text(
                                          "RSSI: ${metrics.rssi} dBm",
                                          style: const TextStyle(
                                              color: Colors.white70),
                                        ),
                                        Text(
                                          "Smoothed RSSI: ${metrics.smoothedRssi.toStringAsFixed(2)} dBm",
                                          style: const TextStyle(
                                              color: Colors.white70),
                                        ),
                                        Text(
                                          "Avg RSSI: ${metrics.averageRssi.toStringAsFixed(2)} dBm",
                                          style: const TextStyle(
                                              color: Colors.white70),
                                        ),
                                        Text(
                                          "Min/Max RSSI: ${metrics.minRssi} / ${metrics.maxRssi}",
                                          style: const TextStyle(
                                              color: Colors.white70),
                                        ),
                                        Text(
                                          "Readings: ${metrics.totalReadings}",
                                          style: const TextStyle(
                                              color: Colors.white70),
                                        ),
                                        Text(
                                          "Connectable: ${metrics.advertisementData.connectable}",
                                          style: const TextStyle(
                                              color: Colors.white70),
                                        ),
                                        Text(
                                          "Seen: ${metrics.timeSinceLastSeen.inSeconds}s ago",
                                          style: const TextStyle(
                                              color: Colors.white70),
                                        ),
                                        Text(
                                          "Latency: ${metrics.latencyMs != null ? '${metrics.latencyMs} ms' : 'N/A'}",
                                          style: const TextStyle(
                                              color: Colors.white70),
                                        ),
                                      ],
                                    ],
                                  ),
                                  trailing: Text(
                                    data.device.platformName,
                                    style:
                                        const TextStyle(color: Colors.white70),
                                  ),
                                ),
                              );
                            },
                          );
                        }),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
