@echo off
echo Starting complete fix process for Flutter app...

REM Clean the project first
call flutter clean

REM Update Flutter and dependencies
echo Updating Flutter SDK...
call flutter upgrade

REM Remove problematic packages
echo Removing problematic packages...
call flutter pub remove purchases_ui_flutter

REM Add compatible versions
echo Adding compatible packages...
call flutter pub add purchases_flutter:^6.0.0 --no-precompile

REM Apply custom gradle fixes
echo Applying Gradle fixes...
call android\fix_gradle.bat

REM Fix plugin Android namespaces
echo Fixing plugin namespaces...
cd %LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\flutter_plugin_android_lifecycle-*\android
if exist build.gradle (
  echo // Fix for namespace issues > fix_namespace.gradle
  echo android { >> fix_namespace.gradle
  echo   namespace "io.flutter.plugins.flutter_plugin_android_lifecycle" >> fix_namespace.gradle
  echo } >> fix_namespace.gradle
  echo apply from: "fix_namespace.gradle" >> build.gradle
)
cd ..\..\..\..\..\..

REM Build the project
echo Building project to verify fixes...
call flutter build apk --debug --verbose

echo All fixes applied. Try running your app now.
pause 