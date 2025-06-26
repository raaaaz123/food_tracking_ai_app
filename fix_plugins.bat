@echo off
echo Fixing specific plugin issues...

REM Clean the Flutter project
call flutter clean

REM Fix old plugins by updating to newer versions
call flutter pub outdated
call flutter pub upgrade --major-versions

REM Remove problematic packages
call flutter pub remove purchases_ui_flutter

REM Add explicit compatible versions
call flutter pub add purchases_flutter:^6.0.0
call flutter pub add flutter_plugin_android_lifecycle:^2.0.15

REM Create fixes for common plugin issues
cd %LOCALAPPDATA%\Pub\Cache\hosted\pub.dev

REM Fix flutter_plugin_android_lifecycle
cd flutter_plugin_android_lifecycle-*\android
if exist build.gradle (
  echo android { namespace "io.flutter.plugins.flutter_plugin_android_lifecycle" } > fix_namespace.gradle
  findstr /v /c:"apply from: \"fix_namespace.gradle\"" build.gradle > build.gradle.new
  echo apply from: \"fix_namespace.gradle\" >> build.gradle.new
  move /y build.gradle.new build.gradle
)
cd ..\..

REM Add namespace to image_picker_android if needed
cd image_picker_android-*\android
if exist build.gradle (
  echo android { namespace "io.flutter.plugins.imagepicker" } > fix_namespace.gradle
  findstr /v /c:"apply from: \"fix_namespace.gradle\"" build.gradle > build.gradle.new
  echo apply from: \"fix_namespace.gradle\" >> build.gradle.new
  move /y build.gradle.new build.gradle
)
cd ..\..\..\..\..

REM Return to project directory
cd %~dp0

echo Plugin fixes applied. Try building your app now.
pause 