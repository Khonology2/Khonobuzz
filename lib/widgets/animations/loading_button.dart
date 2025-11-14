import 'package:flutter/material.dart';

class LoadingConfirmButton extends StatefulWidget {
  final String text;
  final Color color;
  final Future<void> Function() onPressed;

  const LoadingConfirmButton({
    super.key,
    required this.text,
    required this.color,
    required this.onPressed,
  });

  @override
  State<LoadingConfirmButton> createState() => _LoadingConfirmButtonState();
}

class _LoadingConfirmButtonState extends State<LoadingConfirmButton> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      child: ElevatedButton(
        onPressed: _loading
            ? null
            : () async {
                setState(() => _loading = true);
                try {
                  await widget.onPressed();
                } finally {
                  if (mounted) setState(() => _loading = false);
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: widget.color,
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          shape: const StadiumBorder(),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: _loading
              ? const SizedBox(
                  key: ValueKey('loader'),
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC10D00)),
                  ),
                )
              : Text(
                  widget.text,
                  key: const ValueKey('text'),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }
}
