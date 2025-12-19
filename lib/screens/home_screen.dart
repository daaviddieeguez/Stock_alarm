import 'package:flutter/material.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            'Monitor activo en segundo plano',
            style: TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}
