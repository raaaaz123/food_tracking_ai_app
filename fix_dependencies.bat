@echo off
echo Fixing dependencies issues...

REM Clean the project first
call flutter clean

REM Remove problematic packages and use compatible versions
call flutter pub remove purchases_ui_flutter
call flutter pub add purchases_flutter:^6.0.0 --no-precompile

REM Fix the Android gradle configuration
call android\fix_gradle.bat

echo All dependencies fixed. Try building again.
pause 