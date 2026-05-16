import 'package:flutter/material.dart';

class TimerPopup extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<HighlightText>? highlights;
  final String? description;

  final String leftButtonText;
  final VoidCallback? onLeftPressed;

  final String rightButtonText;
  final VoidCallback? onRightPressed;

  final bool singleButton;

  const TimerPopup({
    super.key,
    required this.title,
    this.subtitle,
    this.highlights,
    this.description,
    this.leftButtonText = '',
    this.onLeftPressed,
    this.rightButtonText = '',
    this.onRightPressed,
    this.singleButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            /// 타이틀
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),

            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14),
              ),
            ],

            if (highlights != null && highlights!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Column(
                children: highlights!
                    .map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    "${e.label}: ${e.value}",
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ))
                    .toList(),
              ),
            ],

            if (description != null) ...[
              const SizedBox(height: 12),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],

            const SizedBox(height: 20),

            /// 버튼 영역
            if (singleButton)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onRightPressed,
                  child: Text(rightButtonText),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onLeftPressed,
                      child: Text(leftButtonText),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onRightPressed,
                      child: Text(rightButtonText),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class HighlightText {
  final String label;
  final String value;

  HighlightText({required this.label, required this.value});
}