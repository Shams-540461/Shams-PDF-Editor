@echo off
setlocal
cd /d "%~dp0"
where flutter >nul 2>nul
if errorlevel 1 (
  echo Flutter was not found. Add your Flutter bin folder to PATH, then reopen CMD.
  exit /b 1
)
call flutter pub get
if errorlevel 1 exit /b 1
call dart tool/prepare_web.dart
if errorlevel 1 exit /b 1
call flutter analyze
if errorlevel 1 exit /b 1
call flutter test
if errorlevel 1 exit /b 1
call flutter run -d chrome
