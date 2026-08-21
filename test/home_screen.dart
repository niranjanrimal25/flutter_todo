import 'package:flutter/material.dart';
import 'package:todo_app/widgets/nepali_calendar_widget.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Todo App'),
      ),
      body: const SingleChildScrollView(
        child: Column(
          children: [NepaliCalendarWidget()],
        ),
      ),
    );
  }
}
