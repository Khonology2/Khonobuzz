import 'package:flutter/material.dart';

class ResourceAllocationScreen extends StatelessWidget {
  const ResourceAllocationScreen({super.key});

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
        child: const Center(child: Text('Resource Allocation Content')),
      ),
    );
  }
}
