#!/bin/bash
# Codespaces-only: register the WPILib VSIX with the running VS Code Server.
# postCreate runs before `code` exists; the Dockerfile already unpacked the files
# for local Dev Containers.
set -euo pipefail

if [ "${CODESPACES:-}" != "true" ]; then
  exit 0
fi

WPILIB_VSIX_VERSION="2027.0.0-alpha-7"
echo "Installing WPILib VS Code extension ${WPILIB_VSIX_VERSION}..."
wget -q "https://github.com/wpilibsuite/vscode-wpilib/releases/download/v${WPILIB_VSIX_VERSION}/vscode-wpilib-${WPILIB_VSIX_VERSION}.vsix" \
  -O /tmp/vscode-wpilib.vsix
code --install-extension /tmp/vscode-wpilib.vsix --force
rm -f /tmp/vscode-wpilib.vsix
