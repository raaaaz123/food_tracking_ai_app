import 'package:flutter/services.dart';
import 'package:rive/rive.dart';

class RiveUtils {
  // Load a Rive file from assets
  static Future<RiveFile> loadRiveFile(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    return RiveFile.import(data);
  }

  // Create a simple Rive controller for an animation
  static StateMachineController? getRiveController(
    Artboard artboard, {
    required String stateMachineName,
  }) {
    StateMachineController? controller = 
        StateMachineController.fromArtboard(artboard, stateMachineName);
    if (controller != null) {
      artboard.addController(controller);
    }
    return controller;
  }
}

class NutritionCardRiveController {
  late RiveAnimationController _controller;
  late Artboard _artboard;
  
  // Create a simple animation controller that plays a single animation
  NutritionCardRiveController() {
    _controller = SimpleAnimation('idle');
  }
  
  Future<void> init(String assetPath) async {
    final file = await RiveUtils.loadRiveFile(assetPath);
    _artboard = file.mainArtboard;
    _artboard.addController(_controller);
  }
  
  Artboard get artboard => _artboard;
  
  void dispose() {
    _controller.dispose();
  }
} 