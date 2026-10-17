#!/bin/bash
# Fake a 2027 WPILib installer layout, download desktop tools, and warm Gradle
# so IntelliSense works on a cold Codespace.
set -euo pipefail

WPILIB_YEAR="2027_alpha7"
WPILIB_VER="2027.0.0-alpha-7"
FRCMAVEN="https://frcmaven.wpi.edu/artifactory/release/org/wpilib/tools"
ADVANTAGESCOPE_VER="27.0.0-alpha-5"
ELASTIC_VER="2027.0.0-alpha8"

if [ -n "${XDG_DATA_HOME:-}" ] && [[ "$XDG_DATA_HOME" == /* ]]; then
  WPILIB_HOME="${XDG_DATA_HOME}/wpilib/${WPILIB_YEAR}"
else
  WPILIB_HOME="${HOME}/.local/share/wpilib/${WPILIB_YEAR}"
fi
TOOLS_DIR="${WPILIB_HOME}/tools"

if [ -n "${JAVA_HOME:-}" ] && [ -d "$JAVA_HOME" ]; then
  WPILIB_JDK="$JAVA_HOME"
else
  WPILIB_JDK="$(readlink -f "$(command -v java)" | sed 's|/bin/java$||')"
fi
echo "WPILib home: ${WPILIB_HOME}"
echo "Using JDK at: ${WPILIB_JDK}"

mkdir -p "${WPILIB_HOME}/maven" "$TOOLS_DIR"
ln -sfn "$WPILIB_JDK" "${WPILIB_HOME}/jdk"

merge_java_settings() {
  local settings_path="$1"
  mkdir -p "$(dirname "$settings_path")"
  python3 - "$settings_path" "$WPILIB_JDK" <<'PY'
import json, os, sys
path, jdk = sys.argv[1], sys.argv[2]
settings = {}
if os.path.exists(path):
    with open(path, encoding="utf-8") as f:
        try:
            settings = json.load(f)
        except json.JSONDecodeError:
            settings = {}
settings["java.jdt.ls.java.home"] = jdk
settings["java.configuration.runtimes"] = [
    {"name": "JavaSE-25", "path": jdk, "default": True}
]
with open(path, "w", encoding="utf-8") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")
PY
}

# Keep container JDK paths out of the repo's .vscode/settings.json.
merge_java_settings "${HOME}/.vscode-server/data/User/settings.json"
if [ -d "${HOME}/.vscode-remote/data/User" ] || [ "${CODESPACES:-}" = "true" ]; then
  merge_java_settings "${HOME}/.vscode-remote/data/User/settings.json"
fi

rm -rf "${HOME}/.vscode-server/data/User/workspaceStorage/"*/redhat.java
rm -rf "${HOME}/.vscode-remote/data/User/workspaceStorage/"*/redhat.java

install_native_tool() {
  local artifact="$1"
  local zip_bin="$2"
  echo "Installing ${artifact}..."
  wget -q "${FRCMAVEN}/${artifact}/${WPILIB_VER}/${artifact}-${WPILIB_VER}-linuxx86-64.zip" \
    -O "/tmp/${artifact}.zip"
  unzip -p "/tmp/${artifact}.zip" "linux/x86-64/${zip_bin}" > "${TOOLS_DIR}/${artifact}"
  chmod +x "${TOOLS_DIR}/${artifact}"
  local lower
  lower="$(printf '%s' "$artifact" | tr '[:upper:]' '[:lower:]')"
  if [ "$lower" != "$artifact" ]; then
    ln -sfn "$artifact" "${TOOLS_DIR}/${lower}"
  fi
  rm -f "/tmp/${artifact}.zip"
}

# GradleRIO looks up PascalCase names; vscode-wpilib on Linux uses lowercased tools.json names.
install_native_tool "OutlineViewer" "outlineviewer"
install_native_tool "Glass" "glass"
install_native_tool "SysId" "sysid"
install_native_tool "DataLogTool" "datalogtool"
install_native_tool "wpical" "wpical"

echo "Installing AdvantageScope..."
mkdir -p "${WPILIB_HOME}/advantagescope"
wget -q "https://github.com/Mechanical-Advantage/AdvantageScope/releases/download/v${ADVANTAGESCOPE_VER}/advantagescope-wpilib-linux-x64.zip" \
  -O /tmp/advantagescope.zip
unzip -qo /tmp/advantagescope.zip -d "${WPILIB_HOME}/advantagescope"
chmod +x "${WPILIB_HOME}/advantagescope/advantagescope-wpilib"
cat > "${TOOLS_DIR}/AdvantageScope" <<LAUNCHER
#!/bin/bash
cd "${WPILIB_HOME}/advantagescope"
exec ./advantagescope-wpilib --no-sandbox "\$@"
LAUNCHER
chmod +x "${TOOLS_DIR}/AdvantageScope"
ln -sfn AdvantageScope "${TOOLS_DIR}/advantagescope"
rm -f /tmp/advantagescope.zip

echo "Installing Elastic..."
mkdir -p "${WPILIB_HOME}/elastic"
wget -q "https://github.com/Gold872/elastic_dashboard/releases/download/v${ELASTIC_VER}/Elastic-WPILib-Linux.zip" \
  -O /tmp/elastic.zip
unzip -qo /tmp/elastic.zip -d "${WPILIB_HOME}/elastic"
chmod +x "${WPILIB_HOME}/elastic/elastic_dashboard"
cat > "${TOOLS_DIR}/Elastic" <<LAUNCHER
#!/bin/bash
cd "${WPILIB_HOME}/elastic"
exec ./elastic_dashboard "\$@"
LAUNCHER
chmod +x "${TOOLS_DIR}/Elastic"
ln -sfn Elastic "${TOOLS_DIR}/elastic"
rm -f /tmp/elastic.zip

cat > "${TOOLS_DIR}/tools.json" <<EOF
[
  {"name": "OutlineViewer", "version": "${WPILIB_VER}"},
  {"name": "Glass", "version": "${WPILIB_VER}"},
  {"name": "SysId", "version": "${WPILIB_VER}"},
  {"name": "DataLogTool", "version": "${WPILIB_VER}"},
  {"name": "wpical", "version": "${WPILIB_VER}"},
  {"name": "AdvantageScope", "version": "${ADVANTAGESCOPE_VER}"},
  {"name": "Elastic", "version": "${ELASTIC_VER}"}
]
EOF

PATH_LINE="export PATH=\"${TOOLS_DIR}:\$PATH\""
for rc in "${HOME}/.bashrc" "${HOME}/.zshrc"; do
  if [ -f "$rc" ] && grep -Fq "$TOOLS_DIR" "$rc"; then
    continue
  fi
  printf '\n# WPILib 2027 tools\n%s\n' "$PATH_LINE" >> "$rc"
done

# Fluxbox (not postStart) owns GUI autostart so AdvantageScope survives the
# Dev Container process group. -desktop fluxbox still exec's ~/.fluxbox/startup
# when that file is executable.
mkdir -p "${HOME}/.fluxbox"
FLUXBOX_STARTUP="${HOME}/.fluxbox/startup"
if [ ! -f "$FLUXBOX_STARTUP" ] || ! grep -Fq "AdvantageScope" "$FLUXBOX_STARTUP"; then
  cat > "$FLUXBOX_STARTUP" <<EOF
#!/bin/sh
export DISPLAY="\${DISPLAY:-:1}"
(
  sleep 2
  if [ -x "${TOOLS_DIR}/AdvantageScope" ] && ! pgrep -f advantagescope-wpilib >/dev/null; then
    "${TOOLS_DIR}/AdvantageScope"
  fi
) >/tmp/advantagescope.log 2>&1 &
exec fluxbox
EOF
  chmod +x "$FLUXBOX_STARTUP"
fi

# Current VNC session already started fluxbox before this script ran.
if pgrep -x fluxbox >/dev/null && [ -x "${TOOLS_DIR}/AdvantageScope" ]; then
  bash "$(dirname "$0")/start-advantagescope.sh" || true
fi

if [ -f gradlew ]; then
  chmod +x gradlew
  echo "Warming Gradle cache (first run downloads WPILib + vendor JARs)..."
  ./gradlew compileJava --no-daemon
fi

cat <<EOF

WPILib 2027 sim container is ready.

  Desktop: open forwarded port 6080 (password: vscode)
  Build:   ./gradlew compileJava
  Sim:     ./gradlew run
           or Command Palette → WPILib: Simulate Robot Code

The sim GUI appears on the noVNC desktop, not in this terminal.

EOF
