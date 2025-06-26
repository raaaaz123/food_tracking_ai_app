import 'package:flutter/material.dart';
import '../models/workout_plan.dart';
import '../services/workout_plan_service.dart';

class WorkoutPlansScreen extends StatefulWidget {
  const WorkoutPlansScreen({Key? key}) : super(key: key);

  @override
  State<WorkoutPlansScreen> createState() => _WorkoutPlansScreenState();
}

class _WorkoutPlansScreenState extends State<WorkoutPlansScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workout Plans'),
      ),
      body: FutureBuilder<List<WorkoutPlan>>(
        future: WorkoutPlanService.getAllPlans(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text('No workout plans available'),
            );
          }

        return ListView.builder(
            itemCount: snapshot.data!.length,
          itemBuilder: (context, index) {
              final plan = snapshot.data![index];
              return ListTile(
                title: Text(plan.name),
                subtitle: Text(plan.description),
                trailing: Text('${plan.exercises.length} exercises'),
                onTap: () {
                  // TODO: Navigate to plan details
          },
        );
      },
          );
        },
      ),
    );
  }
} 