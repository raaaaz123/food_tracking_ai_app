import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'screens/main_app_screen.dart';
import 'screens/diet_plan_result_screen.dart';
import 'services/theme_service.dart';
import 'services/preferences_service.dart';
import 'services/nutrition_service.dart';
import 'services/meal_plan_service.dart';
import 'services/audio_service.dart';
import 'services/google_health_service.dart';
import 'services/update_service.dart';
import 'services/storage_service.dart';
import 'services/food_hive_service.dart';
import 'services/exercise_hive_service.dart';
import 'services/firebase_service.dart';
import 'services/subscription_handler.dart';
import 'models/meal_suggestion.dart';

import 'screens/intro_screen.dart';
import 'models/user_details.dart';
import 'models/food_hive_model.dart';
import 'models/workout_plan.dart';
import 'models/user_metrics_history.dart';
import 'adapters/exercise_adapter.dart';
import 'dart:async';
import 'services/widget_service.dart';
import 'package:home_widget/home_widget.dart';
import 'screens/get_started_screen.dart';
import 'constants/app_colors.dart';
import 'screens/nutrition_card_demo_screen.dart';
import 'dart:io';
// Fallback widget import 'package:flutter_native_timezone/flutter_native_timezone.dart';in case of critical errors
import 'services/api_key_service.dart';

import 'package:nutrizen_ai/services/notification_service.dart';

// Add MealSuggestion adapter
class MealSuggestionAdapter extends TypeAdapter<MealSuggestion> {
  @override
  final int typeId = 6;

  @override
  MealSuggestion read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MealSuggestion(
      name: fields[0] as String,
      description: fields[1] as String,
      nutritionInfo: (fields[2] as Map).cast<String, dynamic>(),
      ingredients: (fields[3] as List).cast<String>(),
      instructions: fields[4] as String,
      imageUrl: fields[5] as String,
      mealType: fields[6] as String,
      cuisine: fields[7] as String,
      region: fields[8] as String,
      createdAt: fields[9] as DateTime,
      audioUrl: fields[10] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, MealSuggestion obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.description)
      ..writeByte(2)
      ..write(obj.nutritionInfo)
      ..writeByte(3)
      ..write(obj.ingredients)
      ..writeByte(4)
      ..write(obj.instructions)
      ..writeByte(5)
      ..write(obj.imageUrl)
      ..writeByte(6)
      ..write(obj.mealType)
      ..writeByte(7)
      ..write(obj.cuisine)
      ..writeByte(8)
      ..write(obj.region)
      ..writeByte(9)
      ..write(obj.createdAt)
      ..writeByte(10)
      ..write(obj.audioUrl);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MealSuggestionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ErrorFallbackScreen extends StatelessWidget {
  final String? message;
  const ErrorFallbackScreen({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 50, color: Colors.red),
              const SizedBox(height: 20),
              Text(
                message ?? 'An error occurred',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _registerHiveAdapters() async {
  // User details adapter (typeId 0)
  try {
    if (!Hive.isAdapterRegistered(0)) {
     
      Hive.registerAdapter(UserDetailsAdapter());
    
    } else {
     
    }
  } catch (e) {
   
    // Continue even if registration fails
  }

  // Food Hive Model adapter (typeId 1)
  try {
     
      Hive.registerAdapter(FoodHiveModelAdapter());
  } catch (e) {
    

    // Try again with forced registration as a recovery mechanism
    try {
      
      // Force registration by using a different typeId temporarily
      Hive.registerAdapter(FoodHiveModelAdapter(), override: true);
    
    } catch (retryError) {
      
    }
  }

  // Exercise adapter (typeId 2)
  try {
    if (!Hive.isAdapterRegistered(2)) {
      
      Hive.registerAdapter(ExerciseAdapter());
     
    } else {
     
    }
  } catch (e) {
   

    // Try again with forced registration
    try {
     
      Hive.registerAdapter(ExerciseAdapter(), override: true);
     
    } catch (retryError) {
      
    }
  }

  // Workout Plan adapters (typeId 3 & 4)
  try {
    if (!Hive.isAdapterRegistered(3)) {
      
      Hive.registerAdapter(WorkoutPlanAdapter());
    } else {
      
    }

    if (!Hive.isAdapterRegistered(4)) {
   
      Hive.registerAdapter(WorkoutExerciseAdapter());
     
    } else {
     
    }
  } catch (e) {
   
    // Continue even if registration fails
  }

  // User Metrics History adapter (typeId 5)
  try {
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(UserMetricsHistoryAdapter());
    }
  } catch (e) {
    // Continue even if registration fails
  }
  
  // MealSuggestion adapter (typeId 6)
  try {
    if (!Hive.isAdapterRegistered(6)) {
      print('📦 Registering MealSuggestion adapter');
      Hive.registerAdapter(MealSuggestionAdapter());
      print('✅ MealSuggestion adapter registered successfully');
    } else {
      print('ℹ️ MealSuggestion adapter already registered');
    }
  } catch (e) {
    print('❌ Error registering MealSuggestion adapter: $e');
    // Try again with forced registration
    try {
      Hive.registerAdapter(MealSuggestionAdapter(), override: true);
      print('✅ MealSuggestion adapter registered with override');
    } catch (retryError) {
      print('❌ Failed to register MealSuggestion adapter even with override: $retryError');
    }
  }
}

Future<void> _initializeHiveBoxes() async {
  try {
    // Ensure Hive boxes are properly opened
    await Hive.openBox<WorkoutPlan>('workoutPlans');
    
    // Open meal suggestions box with compaction strategy
    await Hive.openBox<MealSuggestion>('mealSuggestions', 
        compactionStrategy: (entries, deletedEntries) => deletedEntries > 50);
    
    // Log status
    debugPrint('✅ Hive boxes initialized successfully');
    
    // Verify meal suggestions box
    final box = Hive.box<MealSuggestion>('mealSuggestions');
    final suggestions = box.values.toList();
    debugPrint('📦 Found ${suggestions.length} meal suggestions in Hive box');
    
    // Log first suggestion if available
    if (suggestions.isNotEmpty) {
      debugPrint('🔍 First suggestion: ${suggestions.first.name}');
    }
  } catch (e) {
    debugPrint('❌ Error initializing Hive boxes: $e');
    // Try recovery
    try {
      await Hive.openBox<MealSuggestion>('mealSuggestions');
    } catch (e2) {
      debugPrint('❌ Recovery failed: $e2');
    }
  }
}

Future<void> main() async {
  // Catch any error during startup
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
  };
  
  runZonedGuarded(() async {
    try {
      WidgetsFlutterBinding.ensureInitialized();

      // Initialize HomeWidget
      await WidgetService.initWidget();
      
      // Force portrait mode only
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      
      // Set global system UI style with black status bar icons
      SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ));

      // Initialize Hive
      await Hive.initFlutter();

      // Register Hive adapters in a controlled way
      await _registerHiveAdapters();
      
      // Ensure Hive boxes are properly opened
      await _initializeHiveBoxes();
      
      // Initialize storage services with timeouts and error handling
      try {
        await StorageService.initialize().timeout(
          Duration(seconds: 3),
          onTimeout: () {
          
            return;
          }
        );
      } catch (e) {
      
        // Continue without full storage functionality
      }
      
      try {
        await FoodHiveService.init().timeout(
          Duration(seconds: 3),
          onTimeout: () {
           
            return;
          }
        );
      } catch (e) {
      
        // Continue without food storage
      }

      // Explicitly initialize ExerciseHiveService with timeout
      try {
        await ExerciseHiveService.init().timeout(
          Duration(seconds: 3),
          onTimeout: () {

            return;
          }
        );
      } catch (e) {
 
        // Continue without exercise storage
      }

      // Try to initialize Firebase first, as API keys rely on it
      try {
   
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );

        // Initialize Crashlytics
        await FirebaseCrashlytics.instance
            .setCrashlyticsCollectionEnabled(true);

        // Pass all uncaught errors from the framework to Crashlytics
        FlutterError.onError =
            FirebaseCrashlytics.instance.recordFlutterFatalError;
        
        // Initialize Firebase services 
        await FirebaseService.initialize();
        
        // Initialize Firebase Remote Config for secure API keys
  
        await ApiKeyService.initialize();
        
        // Initialize subscription service
        try {
          await SubscriptionHandler.init();
        } catch (e) {
      
          // Continue even if SubscriptionService initialization fails
        }
      } catch (e) {
   
        // Continue without Firebase, but note that API keys will be unavailable
      }
      
      // Initialize MealPlanService
      try {
        // First make sure the box is opened properly
        if (!Hive.isBoxOpen('mealSuggestions')) {
          await Hive.openBox<MealSuggestion>('mealSuggestions', 
              compactionStrategy: (entries, deletedEntries) => deletedEntries > 50);
        }
        
        await MealPlanService.initialize();
        debugPrint('✅ MealPlanService initialized successfully');
        
        // Verify the meal suggestions box is open
        final box = Hive.box<MealSuggestion>('mealSuggestions');
        debugPrint('📦 Meal suggestions box opened: ${box.isOpen}');
        
        // Check if there are any existing meal suggestions
        final suggestions = box.values.toList();
        debugPrint('🍽️ Found ${suggestions.length} existing meal suggestions');
        
        // Verify data structure
        if (suggestions.isNotEmpty) {
          debugPrint('🔍 First suggestion sample: ${suggestions.first.name}');
        }
        
      } catch (e) {
        debugPrint('❌ Failed to initialize MealPlanService: $e');
        // Try recovery initialization
        try {
          await Hive.openBox<MealSuggestion>('mealSuggestions', 
              compactionStrategy: (entries, deletedEntries) => deletedEntries > 50);
          await MealPlanService.initialize();
        } catch (e2) {
          debugPrint('❌ Recovery initialization failed: $e2');
        }
      }
      
      // Initialize AudioService
      try {
        await AudioService.initialize();
      } catch (e) {
        debugPrint('Failed to initialize AudioService: $e');
        // Continue even if AudioService initialization fails
      }

      // Set system UI mode
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.edgeToEdge,
        overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
      );

      // Initialize home screen widgets with debug logging
      try {
       
      await WidgetService.initWidget();
       
      } catch (e) {
       
      }

      // Register for widget updates
      HomeWidget.widgetClicked.listen((uri) {
        // Handle widget clicks here
       
      });

      // Default widget to show
      Widget initialScreen = const GetStartedScreen(); // Changed to GetStartedScreen

      try {
        // Check if we have the required data in storage
        final userDetails = await StorageService.getUserDetails();
        var nutritionPlan = await StorageService.getNutritionPlan();

        // Make decision based on data presence
        if (userDetails != null && nutritionPlan != null) {
          // User has completed onboarding, go directly to main app screen
          initialScreen = const MainAppScreen();
        }
      } catch (e, stackTrace) {
        // If error during data loading, go to get started screen
        initialScreen = const GetStartedScreen();
      }

      // Initialize PostHog with error handling
      try {
        final config = PostHogConfig('phc_ce34ExNJofZxN3U9Wynrp1IF8ubWIn3VM9toXtwbtzF');
        config.debug = true;
        config.captureApplicationLifecycleEvents = true;
        config.host = 'https://us.i.posthog.com';
        await Posthog().setup(config);
      } catch (e) {
       
        // Continue without analytics
      }
      
      // Initialize OneSignal with error handling
      try {
        OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
        OneSignal.initialize("873d8c9c-cdee-4a57-9432-206545b1d572");
      } catch (e) {
       
        // Continue without push notifications
      }

      // Initialize app
      var userDetails = await StorageService.getUserDetails();
      var nutritionPlan = await StorageService.getNutritionPlan();
      
      if (userDetails != null && nutritionPlan != null) {
        // Update home screen widget on app start
        try {
        
          await WidgetService.updateNutritionWidget();
        } catch (e) {
         
        }
      }

      // Run the actual app
      runApp(MyApp(
        themeMode: ThemeMode.light,
        initialScreen: initialScreen,
      ));
    } catch (e, stackTrace) {
     
      runApp(ErrorFallbackScreen(
        message: 'App initialization failed.\nPlease restart the app.',
      ));
    }
  }, (error, stackTrace) {
    
  });
}

class MyApp extends StatelessWidget {
  final ThemeMode themeMode;
  final Widget initialScreen;

  const MyApp(
      {super.key, required this.themeMode, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dietly AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeService.lightTheme,
      darkTheme: ThemeService.lightTheme,
      themeMode: themeMode,
      initialRoute: '/',
      routes: {
        '/': (context) => ExitConfirmationWrapper(
              child: UpdateCheckWrapper(
                child: initialScreen,
              ),
            ),
        '/nutrition_card_demo': (context) => const NutritionCardDemoScreen(),
      },
    );
  }
}

/// Wrapper that handles app exit confirmation
class ExitConfirmationWrapper extends StatelessWidget {
  final Widget child;

  const ExitConfirmationWrapper({Key? key, required this.child})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Show exit confirmation dialog
        return await _showExitConfirmationDialog(context) ?? false;
      },
      child: child,
    );
  }

  // App exit confirmation dialog
  Future<bool?> _showExitConfirmationDialog(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = AppColors.primary;

    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.exit_to_app,
                  size: 36,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Exit App',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to exit the app?',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Cancel button
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Colors.grey.withOpacity(0.2),
                            width: 1,
                          ),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Exit button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(true);
                        SystemNavigator.pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text('Exit'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UpdateCheckWrapper extends StatefulWidget {
  final Widget child;

  const UpdateCheckWrapper({super.key, required this.child});

  @override
  State<UpdateCheckWrapper> createState() => _UpdateCheckWrapperState();
}

class _UpdateCheckWrapperState extends State<UpdateCheckWrapper> {
  @override
  void initState() {
    super.initState();
    // Check for updates after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.checkForUpdates(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
