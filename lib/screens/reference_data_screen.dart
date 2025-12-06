import 'package:flutter/material.dart';

class ReferenceDataScreen extends StatelessWidget {
  const ReferenceDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Reference Data Screen'),
        backgroundColor: const Color(0xFFC10D00),
        elevation: 0.0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/Niice_Wrld_A_dark,_abstract_background_with_a_black_background_and_a_red_lin_ce144728-8a69-4c91-9aa3-069deb283a9c.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: const Center(
          child: Text('Reference Data Content'),
        ),
      ),
    );
  }
}
