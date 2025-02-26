import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:smarttendance/components/button.dart';
import 'package:smarttendance/components/textfields.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:smarttendance/pages/student_home_page.dart';
import 'package:smarttendance/pages/professor_home_page.dart';
import 'package:smarttendance/services/firestore.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void signUserIn() async {
    if (!_formKey.currentState!.validate()) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      User? user = userCredential.user;

      if (user != null) {
        bool isProfessor = await FirestoreService().getProfessors(user.email!);
        bool isStudent = await FirestoreService().getStudents(user.email!);

        if (!mounted) return;
        Navigator.pop(context);

        if (isProfessor) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => ProfessorHomePage()),
          );
        } else if (isStudent) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => StudentHomePage()),
          );
        } else {
          showErrorDialog(
              "Your account is not recognized as a Student or Professor.");
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) Navigator.pop(context);
      showErrorDialog(getCustomErrorMessage(e.code));
    }
  }

  String getCustomErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'network-request-failed':
        return 'Network request failed. Please check your internet connection and try again';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'invalid-email':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      default:
        return 'An unknown error occurred. Please try again.';
    }
  }

  void showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6.0),
          ),
          backgroundColor: Colors.red.shade500,
          title: const Text(
            "Login Error",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.shade300,
                  borderRadius: BorderRadius.circular(6.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(2, 2),
                    ),
                  ],
                ),
                child: const Text(
                  "OK",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blueGrey.shade900,
                      Colors.blueGrey.shade600,
                      Colors.blueGrey.shade400,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              );
            },
          ),
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 30.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'lib/images/fesb_logo.png',
                      height: 120,
                    ).animate().fade(duration: 800.ms),
                    SizedBox(height: 20),
                    Text(
                      'Welcome Back!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ).animate().fade(duration: 1.seconds),
                    Form(
                      key: _formKey,
                      child: Column(
                        children: [
                          SizedBox(height: 20),
                          MyTextField(
                            controller: emailController,
                            hintText: 'username@fesb.hr',
                            obscureText: false,
                          ).animate().fade(duration: 1.seconds),
                          SizedBox(height: 20),
                          MyTextField(
                            controller: passwordController,
                            hintText: 'Password',
                            obscureText: true,
                          ).animate().fade(duration: 1.seconds),
                        ],
                      ),
                    ),
                    SizedBox(height: 40),
                    MyButton(
                      onTap: signUserIn,
                      text: 'Sign in',
                    ).animate().fade(duration: 1.2.seconds),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
