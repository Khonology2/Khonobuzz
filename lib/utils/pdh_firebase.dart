import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

FirebaseApp? _pdhApp;
FirebaseFirestore? _pdhFirestore;

Future<FirebaseFirestore> _getPdhFirestore() async {
  if (_pdhFirestore != null) return _pdhFirestore!;
  _pdhApp ??= await Firebase.initializeApp(
    name: 'pdhApp',
    options: const FirebaseOptions(
      apiKey: 'AIzaSyAjg19Ej8fbUOfa6WYlEX-b4CNi-y0Lozc',
      appId: '1:565445962523:web:a987a77ea9633d308401be',
      messagingSenderId: '565445962523',
      projectId: 'pdh-fe6eb',
      authDomain: 'pdh-fe6eb.firebaseapp.com',
      storageBucket: 'pdh-fe6eb.firebasestorage.app',
    ),
  );
  _pdhFirestore = FirebaseFirestore.instanceFor(app: _pdhApp!);
  return _pdhFirestore!;
}

Future<void> syncUserToPDH(
  Map<String, dynamic> userData,
  Map<String, dynamic> onboardingData,
  String uid,
) async {
  try {
    final fs = await _getPdhFirestore();
    await fs
        .collection('users')
        .doc(uid)
        .set(userData, SetOptions(merge: true));
    await fs
        .collection('onboarding')
        .doc(uid)
        .set(onboardingData, SetOptions(merge: true));
    debugPrint('User and onboarding synced to PDH successfully!');
  } catch (e) {
    debugPrint('Error syncing user to PDH: $e');
  }
}
