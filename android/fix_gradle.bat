@echo off
echo Fixing Flutter plugins namespace issues...

cd %LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\flutter_plugin_android_lifecycle-2.0.28\android
if not exist fix_namespace.gradle (
  echo // Fix for namespace issues > fix_namespace.gradle
  echo android { >> fix_namespace.gradle
  echo   namespace "io.flutter.plugins.flutter_plugin_android_lifecycle" >> fix_namespace.gradle
  echo } >> fix_namespace.gradle
  type fix_namespace.gradle

  echo apply from: "fix_namespace.gradle" >> build.gradle
)

echo All fixes applied. Try building again.
pause 