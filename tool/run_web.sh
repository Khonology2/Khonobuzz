#!/usr/bin/env bash
# Run the Flutter app as web in Chrome from the repository root.
# Usage:  chmod +x tool/run_web.sh && ./tool/run_web.sh
# Other devices:  flutter devices  then  flutter run -d <device_id>

set -euo pipefail
cd "$(dirname "$0")/.."

flutter pub get
flutter run -d chrome
