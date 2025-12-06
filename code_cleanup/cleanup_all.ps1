# PowerShell script to clean all Dart and Python files
# Run this script from the project root directory: C:\apps\pdh\Personal-Development-Hub-Android_Build

Write-Host "Cleaning Dart screen files..." -ForegroundColor Cyan

python code_cleanup\cleanup_dart_comments.py `
  lib/screens/analytics_screen.dart `
  lib/screens/assets_screen.dart `
  lib/screens/auth_screen.dart `
  lib/screens/dashboard_screen.dart `
  lib/screens/entity_management_screen.dart `
  lib/screens/home_screen.dart `
  lib/screens/manual_login_screen.dart `
  lib/screens/khono_bot.dart `
  lib/screens/landing_screen.dart `
  lib/screens/lobby_screen.dart `
  lib/screens/module_access_screen.dart `
  lib/screens/module_screen.dart `
  lib/screens/onboarding_screen.dart `
  lib/screens/profile_screen.dart `
  lib/screens/project_data_screen.dart `
  lib/screens/projects_screen.dart `
  lib/screens/reference_data_screen.dart `
  lib/screens/welcome_screen.dart `
  lib/screens/resource_allocation_screen.dart `
  lib/screens/time_keeping_screen.dart `
  lib/screens/user_management_screen.dart

Write-Host ""
Write-Host "Cleaning Python backend files..." -ForegroundColor Cyan

python code_cleanup\cleanup_python_comments.py `
  backend/fastapi_app.py `
  backend/format_credentials_for_render.py `
  backend/app.py `
  backend/token_utils.py `
  backend/test_config.py `
  backend/config.py

Write-Host ""
Write-Host "Cleanup complete!" -ForegroundColor Green

