import 'package:flutter/material.dart';

import 'screens/schedule_screen.dart';

void main() {
  runApp(const CampusLifeApp());
}

class CampusLifeApp extends StatelessWidget {
  const CampusLifeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CampusLife',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const ScheduleScreen(),
    );
  }
}
