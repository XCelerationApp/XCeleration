import 'package:flutter/material.dart';
import 'app_colors.dart';

class CircularButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final Color color;
  final double fontSize;
  final FontWeight? fontWeight;
  final double elevation;

  const CircularButton({
    required this.onPressed,
    required this.text,
    required this.color,
    this.fontSize = 20,
    this.fontWeight,
    this.elevation = 0,
    super.key,
  });

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
              blurRadius: elevation > 0 ? 4 : 0,
              offset: elevation > 0 ? const Offset(0, 2) : Offset.zero,
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
              fontWeight: fontWeight ?? FontWeight.normal,
            ),
            maxLines: 1,
          ),
        ),
      ),
    );
  }
}

class RoundedRectangleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final Color color;
  final double fontSize;
  final double width;
  final double height;

  const RoundedRectangleButton({
    this.onPressed,
    required this.text,
    required this.color,
    required this.width,
    required this.height,
    this.fontSize = 20,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.rectangle,
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
          borderRadius: BorderRadius.all(Radius.circular(40)),
        ),
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(40)),
            ),
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