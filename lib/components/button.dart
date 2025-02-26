import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class MyButton extends StatefulWidget {
  final Function()? onTap;
  final String text;
  final Color startColor;
  final Color endColor;

  const MyButton({
    super.key,
    required this.onTap,
    required this.text,
    this.startColor = Colors.black87,
    this.endColor = Colors.indigo,
  });

  @override
  MyButtonState createState() => MyButtonState();
}

class MyButtonState extends State<MyButton> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
  }

  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      child: AnimatedContainer(
        duration: 100.ms,
        transform: _isPressed
            ? Matrix4.translationValues(0, 4, 0)
            : Matrix4.identity(),
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.symmetric(horizontal: 25),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [widget.startColor, widget.endColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.black,
              blurRadius: 6,
              offset: const Offset(2, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            widget.text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
