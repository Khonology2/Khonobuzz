import 'package:flutter/material.dart';

class ProjectsScreen extends StatelessWidget {
  const ProjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Projects Screen'),
        backgroundColor: const Color(0xFFC10D00),
        elevation: 0.0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/nathi_bg.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: const Center(child: Text('Projects Content')),
      ),
    );
  }
}
