#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
WORK_DIR="$(mktemp -d -t flutter-template-XXXXXX)"
trap 'rm -rf "${WORK_DIR}"' EXIT

pushd "${WORK_DIR}" >/dev/null
flutter create --platforms=linux,windows --project-name frontend clean_skeleton >/dev/null
popd >/dev/null

apply_note() {
  local file="$1"
  python3 - "$file" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
text = path.read_text()
note = "# NOTE: Local project overrides live in ../cmake/*_overrides.cmake.\n# Keep this file aligned with the stock Flutter template.\n\n"
if note.strip() in text:
    sys.exit(0)
lines = text.splitlines(keepends=True)
for idx, line in enumerate(lines):
    if line.startswith("project("):
        lines.insert(idx + 1, "\n" + note)
        path.write_text("".join(lines))
        break
else:
    raise SystemExit(f"project(...) anchor not found in {path}")
PY
}

apply_include_hook() {
  local file="$1"
  local relative_path="$2"
  python3 - "$file" "$relative_path" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
relative = sys.argv[2]
text = path.read_text()
hook = ("# BEGIN: local overrides (kept minimal to avoid drift)\n"
        f"if(EXISTS \"${{CMAKE_CURRENT_LIST_DIR}}/{relative}\")\n"
        f"  include(\"${{CMAKE_CURRENT_LIST_DIR}}/{relative}\")\n"
        "endif()\n"
        "# END: local overrides\n")
if "local overrides (kept minimal to avoid drift)" in text:
    sys.exit(0)
marker = "include(flutter/generated_plugins.cmake)\n\n"
if marker not in text:
    raise SystemExit(f"include marker not found in {path}")
text = text.replace(marker, marker + hook + "\n")
path.write_text(text)
PY
}

apply_note "${WORK_DIR}/clean_skeleton/linux/CMakeLists.txt"
apply_include_hook "${WORK_DIR}/clean_skeleton/linux/CMakeLists.txt" "../cmake/linux_overrides.cmake"

apply_note "${WORK_DIR}/clean_skeleton/windows/CMakeLists.txt"
apply_include_hook "${WORK_DIR}/clean_skeleton/windows/CMakeLists.txt" "../cmake/windows_overrides.cmake"

status=0
if ! diff -u "${WORK_DIR}/clean_skeleton/linux/CMakeLists.txt" "${REPO_ROOT}/frontend/linux/CMakeLists.txt"; then
  echo "Linux platform files have drifted from the Flutter template." >&2
  status=1
fi

if ! diff -u "${WORK_DIR}/clean_skeleton/windows/CMakeLists.txt" "${REPO_ROOT}/frontend/windows/CMakeLists.txt"; then
  echo "Windows platform files have drifted from the Flutter template." >&2
  status=1
fi

exit ${status}
