import 'package:flutter/material.dart';
import '../../services/sound_system.dart';

class LoadingConfirmButton extends StatefulWidget {
  final String text;
  final Color color;
  final Future<void> Function() onPressed;
  /// Optional key on the tappable control (e.g. integration / E2E tooling).
  final Key? actionKey;

  const LoadingConfirmButton({
    super.key,
    this.actionKey,
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
    return Semantics(
      label: widget.text,
      button: true,
      child: SizedBox(
        width: 250,
        child: ElevatedButton(
          key: widget.actionKey,
          onPressed: _loading
            ? null
            : () async {
                SoundSystem.playButtonClick();
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
      ),
    );
  }
}
