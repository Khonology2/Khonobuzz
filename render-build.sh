#!/usr/bin/env bash
set -euo pipefail

FLUTTER_DIR="${HOME}/flutter"

if [ ! -d "${FLUTTER_DIR}" ]; then
  git clone https://github.com/flutter/flutter.git --depth 1 --branch stable "${FLUTTER_DIR}"
fi

export PATH="${FLUTTER_DIR}/bin:${PATH}"

flutter config --enable-web
flutter --version
flutter pub get
flutter build web --release --base-href /
