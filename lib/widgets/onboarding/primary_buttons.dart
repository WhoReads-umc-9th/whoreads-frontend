import 'package:flutter/material.dart';

class OutlineActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const OutlineActionButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 51,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Color(0xFFA1A4AC), width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            height: 1.4,
            fontFamily: 'Pretendard Variable',
          ),
        ),
      ),
    );
  }
}

class FilledActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const FilledActionButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 51,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1C1C22),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            height: 1.4,
            fontFamily: 'Pretendard Variable',
          ),
        ),
      ),
    );
  }
}
