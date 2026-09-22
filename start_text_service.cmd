@echo off
setlocal
cd /d "%~dp0"
if not defined SYNCFUSION_LICENSE_KEY (
  echo Set SYNCFUSION_LICENSE_KEY in this CMD window first.
  exit /b 1
)
dotnet build syncfusion_api\ShamsPdfApi.csproj
if errorlevel 1 exit /b 1
dotnet run --project syncfusion_api\ShamsPdfApi.csproj --no-build --no-launch-profile -- --self-test
if errorlevel 1 exit /b 1
dotnet run --project syncfusion_api\ShamsPdfApi.csproj --no-build --no-launch-profile
