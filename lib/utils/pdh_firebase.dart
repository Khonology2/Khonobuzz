import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  final fs = await _getPdhFirestore();
  await fs.collection('users').doc(uid).set(userData, SetOptions(merge: true));
  await fs
      .collection('onboarding')
      .doc(uid)
      .set(onboardingData, SetOptions(merge: true));
}

Future<void> updatePDHUserPartial(
  String uid,
  Map<String, dynamic> userFields, {
  Map<String, dynamic>? onboardingFields,
}) async {
  final fs = await _getPdhFirestore();
  await fs.collection('users').doc(uid).set(userFields, SetOptions(merge: true));
  if (onboardingFields != null) {
    await fs
        .collection('onboarding')
        .doc(uid)
        .set(onboardingFields, SetOptions(merge: true));
  }
}
