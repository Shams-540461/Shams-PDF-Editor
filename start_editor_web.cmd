@echo off
setlocal
cd /d "%~dp0"
call flutter pub get
if errorlevel 1 exit /b 1
call dart tool/prepare_web.dart
if errorlevel 1 exit /b 1
call flutter analyze
if errorlevel 1 exit /b 1
call flutter test
if errorlevel 1 exit /b 1
call flutter run -d web-server --release --web-port 8080 --dart-define=PDF_TEXT_API=http://127.0.0.1:8765/edit
