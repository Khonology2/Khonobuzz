import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'dart:math';

// Made lists static and final for easy access
final List<String> departments = [
  'IT',
  'HR',
  'Finance',
  'Marketing',
  'Operations',
  'Sales',
];
final List<String> designations = [
  'Associate',
  'Specialist',
  'Manager',
  'Director',
  'Intern',
];

final List<Map<String, dynamic>> sampleUsers = [
  {
    'name': 'Alice Brown',
    'email': 'alice.brown@Khonology.com',
    'role': 'Admin',
    'status': 'Active',
  },
  {
    'name': 'Bob Johnson',
    'email': 'bob.johnson@Khonology.com',
    'role': 'Manager',
    'status': 'Active',
  },
  {
    'name': 'Carol Davis',
    'email': 'carol.davis@Khonology.com',
    'role': 'Staff',
    'status': 'Active',
  },
  {
    'name': 'David Miller',
    'email': 'david.miller@Khonology.com',
    'role': 'Staff',
    'status': 'Pending',
  },
  {
    'name': 'Eve Wilson',
    'email': 'eve.wilson@Khonology.com',
    'role': 'Admin',
    'status': 'Inactive',
  },
  {
    'name': 'Frank Moore',
    'email': 'frank.moore@Khonology.com',
    'role': 'Manager',
    'status': 'Active',
  },
  {
    'name': 'Grace Taylor',
    'email': 'grace.taylor@Khonology.com',
    'role': 'Staff',
    'status': 'Active',
  },
  {
    'name': 'Henry Anderson',
    'email': 'henry.anderson@Khonology.com',
    'role': 'Staff',
    'status': 'Pending',
  },
  {
    'name': 'Ivy Thomas',
    'email': 'ivy.thomas@Khonology.com',
    'role': 'Admin',
    'status': 'Active',
  },
  {
    'name': 'Jack Jackson',
    'email': 'jack.jackson@Khonology.com',
    'role': 'Staff',
    'status': 'Active',
  },
  {
    'name': 'Karen White',
    'email': 'karen.white@Khonology.com',
    'role': 'Manager',
    'status': 'Active',
  },
  {
    'name': 'Liam Harris',
    'email': 'liam.harris@Khonology.com',
    'role': 'Staff',
    'status': 'Pending',
  },
  {
    'name': 'Mia Martin',
    'email': 'mia.martin@Khonology.com',
    'role': 'Admin',
    'status': 'Active',
  },
  {
    'name': 'Noah Thompson',
    'email': 'noah.thompson@Khonology.com',
    'role': 'Staff',
    'status': 'Inactive',
  },
  {
    'name': 'Olivia Garcia',
    'email': 'olivia.garcia@Khonology.com',
    'role': 'Manager',
    'status': 'Active',
  },
  {
    'name': 'Paul Rodriguez',
    'email': 'paul.rodriguez@Khonology.com',
    'role': 'Staff',
    'status': 'Active',
  },
  {
    'name': 'Quinn Martinez',
    'email': 'quinn.martinez@Khonology.com',
    'role': 'Admin',
    'status': 'Pending',
  },
  {
    'name': 'Rachel Robinson',
    'email': 'rachel.robinson@Khonology.com',
    'role': 'Staff',
    'status': 'Active',
  },
  {
    'name': 'Sam Clark',
    'email': 'sam.clark@Khonology.com',
    'role': 'Manager',
    'status': 'Active',
  },
  {
    'name': 'Tina Lewis',
    'email': 'tina.lewis@Khonology.com',
    'role': 'Staff',
    'status': 'Inactive',
  },
  {
    'name': 'Uma Lee',
    'email': 'uma.lee@Khonology.com',
    'role': 'Admin',
    'status': 'Active',
  },
  {
    'name': 'Victor Walker',
    'email': 'victor.walker@Khonology.com',
    'role': 'Staff',
    'status': 'Pending',
  },
  {
    'name': 'Wendy Hall',
    'email': 'wendy.hall@Khonology.com',
    'role': 'Manager',
    'status': 'Active',
  },
  {
    'name': 'Xander Allen',
    'email': 'xander.allen@Khonology.com',
    'role': 'Staff',
    'status': 'Active',
  },
  {
    'name': 'Yolanda Young',
    'email': 'yolanda.young@Khonology.com',
    'role': 'Admin',
    'status': 'Inactive',
  },
  {
    'name': 'Zach Hernandez',
    'email': 'zach.hernandez@Khonology.com',
    'role': 'Staff',
    'status': 'Active',
  },
  {
    'name': 'Abigail King',
    'email': 'abigail.king@Khonology.com',
    'role': 'Manager',
    'status': 'Active',
  },
  {
    'name': 'Benjamin Wright',
    'email': 'benjamin.wright@Khonology.com',
    'role': 'Staff',
    'status': 'Pending',
  },
  {
    'name': 'Chloe Lopez',
    'email': 'chloe.lopez@Khonology.com',
    'role': 'Admin',
    'status': 'Active',
  },
  {
    'name': 'Daniel Hill',
    'email': 'daniel.hill@Khonology.com',
    'role': 'Staff',
    'status': 'Active',
  },
  // Added 30 more random users below:
  {
    'name': 'Ethan Green',
    'email': 'ethan.green@Khonology.com',
    'role': 'Staff',
    'status': 'Active',
  },
  {
    'name': 'Isabella Adams',
    'email': 'isabella.adams@Khonology.com',
    'role': 'Manager',
    'status': 'Active',
  },
  {
    'name': 'Jacob Baker',
    'email': 'jacob.baker@Khonology.com',
    'role': 'Staff',
    'status': 'Pending',
  },
  {
    'name': 'Sophia Nelson',
    'email': 'sophia.nelson@Khonology.com',
    'role': 'Admin',
    'status': 'Inactive',
  },
  {
    'name': 'Michael Carter',
    'email': 'michael.carter@Khonology.com',
    'role': 'Staff',
    'status': 'Active',
  },
  {
    'name': 'Emily Roberts',
    'email': 'emily.roberts@Khonology.com',
    'role': 'Manager',
    'status': 'Active',
  },
  {
    'name': 'William Evans',
    'email': 'william.evans@Khonology.com',
    'role': 'Staff',
    'status': 'Pending',
  },
  {
    'name': 'Harper Turner',
    'email': 'harper.turner@Khonology.com',
    'role': 'Admin',
    'status': 'Active',
  },
  {
    'name': 'James Parker',
    'email': 'james.parker@Khonology.com',
    'role': 'Staff',
    'status': 'Inactive',
  },
  {
    'name': 'Evelyn Phillips',
    'email': 'evelyn.phillips@Khonology.com',
    'role': 'Manager',
    'status': 'Active',
  },
  {
    'name': 'Alexander Campbell',
    'email': 'alexander.campbell@Khonology.com',
    'role': 'Staff',
    'status': 'Active',
  },
  {
    'name': 'Aria Mitchell',
    'email': 'aria.mitchell@Khonology.com',
    'role': 'Admin',
    'status': 'Pending',
  },
  {
    'name': 'Matthew Rodriguez',
    'email': 'matthew.rodriguez@Khonology.com',
    'role': 'Staff',
    'status': 'Active',
  },
  {
    'name': 'Scarlett Perez',
    'email': 'scarlett.perez@Khonology.com',
    'role': 'Manager',
    'status': 'Active',
  },
  {
    'name': 'Daniel Ward',
    'email': 'daniel.ward@Khonology.com',
    'role': 'Staff',
    'status': 'Inactive',
  },
  {
    'name': 'Victoria Cox',
    'email': 'victoria.cox@Khonology.com',
    'role': 'Admin',
    'status': 'Active',
  },
  {
    'name': 'Joseph Rogers',
    'email': 'joseph.rogers@Khonology.com',
    'role': 'Staff',
    'status': 'Pending',
  },
  {
    'name': 'Madison Gray',
    'email': 'madison.gray@Khonology.com',
    'role': 'Manager',
    'status': 'Active',
  },
  {
    'name': 'Samuel Price',
    'email': 'samuel.price@Khonology.com',
    'role': 'Staff',
    'status': 'Active',
  },
  {
    'name': 'Elizabeth Myers',
    'email': 'elizabeth.myers@Khonology.com',
    'role': 'Admin',
    'status': 'Inactive',
  },
  {
    'name': 'David Foster',
    'email': 'david.foster@Khonology.com',
    'role': 'Staff',
    'status': 'Active',
  },
  {
    'name': 'Sofia Watson',
    'email': 'sofia.watson@Khonology.com',
    'role': 'Manager',
    'status': 'Active',
  },
  {
    'name': 'Andrew Hughes',
    'email': 'andrew.hughes@Khonology.com',
    'role': 'Staff',
    'status': 'Pending',
  },
  {
    'name': 'Grace Wood',
    'email': 'grace.wood@Khonology.com',
    'role': 'Admin',
    'status': 'Active',
  },
  {
    'name': 'Joshua Brooks',
    'email': 'joshua.brooks@Khonology.com',
    'role': 'Staff',
    'status': 'Inactive',
  },
  {
    'name': 'Ella Kelly',
    'email': 'ella.kelly@Khonology.com',
    'role': 'Manager',
    'status': 'Active',
  },
  {
    'name': 'Christopher Howard',
    'email': 'christopher.howard@Khonology.com',
    'role': 'Staff',
    'status': 'Active',
  },
  {
    'name': 'Ava Sanchez',
    'email': 'ava.sanchez@Khonology.com',
    'role': 'Admin',
    'status': 'Pending',
  },
  {
    'name': 'Ryan Scott',
    'email': 'ryan.scott@Khonology.com',
    'role': 'Staff',
    'status': 'Active',
  },
  {
    'name': 'Chloe Green',
    'email': 'chloe.green@Khonology.com',
    'role': 'Manager',
    'status': 'Active',
  },
];

Future<void> createSampleUsersCollection() async {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final Random random = Random();

  for (var userData in sampleUsers) {
    final String randomDepartment =
        departments[random.nextInt(departments.length)];
    final String randomDesignation =
        designations[random.nextInt(designations.length)];

    await firestore.collection('users').add({
      'name': userData['name'],
      'email': userData['email'],
      'role': userData['role'],
      'status': userData['status'],
      'department': randomDepartment,
      'designation': randomDesignation,
    });
  }

  debugPrint('Sample users collection created successfully!');
}
