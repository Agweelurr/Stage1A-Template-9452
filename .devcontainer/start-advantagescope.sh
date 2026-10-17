#!/bin/bash
# Start AdvantageScope detached from the caller (fluxbox session or a terminal).
# setsid so Dev Container lifecycle scripts cannot reap it with their process group.
set -euo pipefail

export DISPLAY="${DISPLAY:-:1}"

WPILIB_YEAR="2027_alpha7"
if [ -n "${XDG_DATA_HOME:-}" ] && [[ "$XDG_DATA_HOME" == /* ]]; then
  WPILIB_HOME="${XDG_DATA_HOME}/wpilib/${WPILIB_YEAR}"
else
  WPILIB_HOME="${HOME}/.local/share/wpilib/${WPILIB_YEAR}"
fi
LAUNCHER="${WPILIB_HOME}/tools/AdvantageScope"

display_num="${DISPLAY#:}"
x_socket="/tmp/.X11-unix/X${display_num}"

for _ in $(seq 1 30); do
  if [ -S "$x_socket" ]; then
    break
  fi
  sleep 1
done

if [ ! -S "$x_socket" ]; then
  echo "AdvantageScope: display ${DISPLAY} is not up; skipping."
  exit 0
fi

if pgrep -f advantagescope-wpilib >/dev/null; then
  echo "AdvantageScope is already running."
  exit 0
fi

if [ ! -x "$LAUNCHER" ]; then
  echo "AdvantageScope launcher not found at ${LAUNCHER}; skipping."
  exit 0
fi

setsid "$LAUNCHER" >/tmp/advantagescope.log 2>&1 </dev/null &
echo "AdvantageScope started on display ${DISPLAY} (see port 6080)."
