import 'package:flutter/material.dart';
import 'landing_screen.dart';
import 'dart:async';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/Niice_Wrld_A_dark,_abstract_background_with_a_black_background_and_a_red_lin_5c0b8290-cc74-4ad3-97c2-749fd1c67f0d.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/logo.png',
                height: 150,
              ),
              const SizedBox(height: 50),
              const AnimatedTextSwitcher(),
              const SizedBox(height: 50),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LandingScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFC10D00),
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'GET STARTED',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AnimatedTextSwitcher extends StatefulWidget {
  const AnimatedTextSwitcher({super.key});

  @override
  State<AnimatedTextSwitcher> createState() => _AnimatedTextSwitcherState();
}

class _AnimatedTextSwitcherState extends State<AnimatedTextSwitcher> {
  final List<String> quotes = [
    'Innovate faster.',
    'Your digital workflow, simplified.',
    'Code with purpose.',
    'Tech, unboxed.',
    'Seamless from start to finish.',
    'The future of development is here.',
    'Build, test, deploy. All in one.',
    'Empowering tomorrow\'s creators.',
    'Streamline your projects.',
    'Efficiency, redefined.',
    'Unlock your potential.',
    'The only tool you\'ll ever need.',
    'Connect code and collaboration.',
    'Your all-in-one tech hub.',
    'Experience true productivity.',
    'The new standard for innovation.',
    'Design, develop, done.',
    'Intelligence at your fingertips.',
    'Transform your ideas into reality.',
    'Welcome to the future of tech.',
  ];

  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _startQuoteTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Timer? _timer;

  void _startQuoteTimer() {
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted) return;
      setState(() {
        _currentIndex = (_currentIndex + 1) % quotes.length;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return FadeTransition(opacity: animation, child: child);
        },
        child: Text(
          quotes[_currentIndex],
          key: ValueKey<int>(_currentIndex),
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}
