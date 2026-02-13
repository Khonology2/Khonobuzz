import 'package:flutter/material.dart';

class TimeKeepingScreen extends StatelessWidget {
  const TimeKeepingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/nathi_bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: const Center(child: Text('Time Keeping Content')),
      ),
    );
  }
}
