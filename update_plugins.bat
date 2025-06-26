@echo off
echo Updating Flutter plugins to more compatible versions...

REM Clean the project first
call flutter clean

REM Update to more compatible plugin versions
call flutter pub remove purchases_ui_flutter
call flutter pub add purchases_flutter:^6.0.0 --no-precompile
call flutter pub upgrade --major-versions

REM Apply Gradle fixes
call android\fix_gradle.bat

echo Plugins updated. Try building again.
pause 