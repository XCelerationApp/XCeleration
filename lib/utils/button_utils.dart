import 'package:flutter/material.dart';
import 'package:race_timing_app/constants.dart';

class CircularButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final Color color;
  final double fontSize;

  const CircularButton({
    required this.onPressed,
    required this.text,
    required this.color,
    this.fontSize = 20,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      height: 70,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          border: Border.all(
            color: AppColors.backgroundColor,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: color,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shape: const CircleBorder(),
            padding: EdgeInsets.zero,
            elevation: 0,
          ),
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
            ),
            maxLines: 1,
          ),
        ),
      ),
    );
  }
}