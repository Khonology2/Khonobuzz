# Run the Flutter app as web in Chrome from the repository root.
# Usage (PowerShell):  .\tool\run_web.ps1
# Other devices:       flutter devices   then   flutter run -d <device_id>

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

flutter pub get
flutter run -d chrome
