import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:smarttendance/pages/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
        name: 'ble-app',
        options: FirebaseOptions(
            apiKey: "AIzaSyBbRv_zpx2gekxO9GeDpfm9whHsvZ2I5xk",
            authDomain: "ble-attendance-4d245.firebaseapp.com",
            projectId: "ble-attendance-4d245",
            storageBucket: "ble-attendance-4d245.firebasestorage.app",
            messagingSenderId: "57889017014",
            appId: "1:57889017014:web:8002e88cff7ac9785a2a17"));
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginPage(),
    );
  }
}
