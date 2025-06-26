import 'package:flutter/material.dart';

class SavedFoodsScreen extends StatelessWidget {
  const SavedFoodsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Foods'),
        elevation: 0,
        backgroundColor: Colors.green.shade800,
      ),
      body: const Center(
        child: Text(
          'Saved Foods Screen',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
