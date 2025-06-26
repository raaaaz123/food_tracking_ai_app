@echo off
echo Fixing Flutter embedding issues...

REM Clean the project first
call flutter clean

REM Force dependency updates to fix embedding issues
call flutter pub upgrade --major-versions

REM Update specific problematic packages
call flutter pub remove purchases_ui_flutter
call flutter pub add purchases_flutter:^6.0.0 --no-precompile

echo Adding flutter.pluginClass to intermediates
cd android

REM Create fix file for embedding compatibility
echo implementation "androidx.startup:startup-runtime:1.1.1" > embedding-fix.gradle

REM Apply the fix to app-level build.gradle.kts
cd app
REM Add startup-runtime dependency
echo dependencies { >> build.gradle.kts.new
echo     implementation("androidx.startup:startup-runtime:1.1.1") >> build.gradle.kts.new
echo } >> build.gradle.kts.new
type build.gradle.kts >> build.gradle.kts.new
move /y build.gradle.kts.new build.gradle.kts

cd ..
cd ..

echo All embedding issues fixed. Try building again.
pause 