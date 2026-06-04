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
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1C1B1F),
                height: 1.4,
              ),
            ),

            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.black),
              ),
            ],

            if (highlights != null && highlights!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: highlights!.map((e) {
                    final bool isRecord = e.label == '기록';
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "${e.label} : ",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isRecord ? FontWeight.w500 : FontWeight.w600,
                              color: isRecord ? const Color(0xFF49454F) : const Color(0xFFFF5722),
                            ),
                          ),
                          Text(
                            e.value,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isRecord ? const Color(0xFF1C1B1F) : const Color(0xFFFF5722),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],

            if (description != null) ...[
              const SizedBox(height: 16),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF79747E),
                  height: 1.4,
                ),
              ),
            ],

            const SizedBox(height: 24),

            if (singleButton)
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: onRightPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1C1B1F),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: Text(
                    rightButtonText,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed: onLeftPressed,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFCAC4D0)),
                          foregroundColor: const Color(0xFF1C1B1F),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          leftButtonText,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: onRightPressed,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1C1B1F),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                        child: Text(
                          rightButtonText,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
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