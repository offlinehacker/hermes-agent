#!/usr/bin/env bash
# Print the release notes for a Hermes Light build of an upstream tag.
#   release-notes.sh <vX.Y.Z>
set -euo pipefail

tag="${1:?usage: release-notes.sh <vX.Y.Z>}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repo="${GITHUB_REPOSITORY:-offlinehacker/hermes-agent}"
rev="${GITHUB_SHA:-$(git -C "$root" rev-parse HEAD 2>/dev/null || echo unknown)}"

cat <<EOF
Hermes Light ${tag#v}: upstream's \`light\` desktop variant (the desktop client without a bundled
agent runtime), built from [\`$tag\`](https://github.com/NousResearch/hermes-agent/releases/tag/$tag).
Connect it to a \`hermes serve\` gateway, an SSH host or a Hermes Cloud agent on first launch.

Unofficial and unsigned. See the [README](https://github.com/$repo/tree/hermes-light#readme)
for install notes.

| File | Platform |
|---|---|
| \`HermesLight-${tag#v}-linux-x86_64.AppImage\` | Linux x64 |
| \`HermesLight-${tag#v}-linux-arm64.AppImage\` | Linux arm64 |
| \`HermesLight-${tag#v}-mac-arm64.dmg\` / \`.zip\` | macOS Apple silicon |
| \`HermesLight-${tag#v}-mac-x64.dmg\` / \`.zip\` | macOS Intel |

Patches ([\`${rev:0:7}\`](https://github.com/$repo/tree/$rev/patches)):

EOF

shopt -s nullglob
patches=("$root"/patches/*.patch)
[ "${#patches[@]}" -gt 0 ] || echo "- none"
for patch in "${patches[@]}"; do
  # Mail headers fold long subjects onto indented continuation lines.
  subject="$(awk '/^Subject: /{s=$0; while ((getline line) > 0 && line ~ /^ /) s = s line; print s; exit}' "$patch" |
    sed 's/^Subject: \(\[PATCH[^]]*\] \)\{0,1\}//')"
  echo "- $subject"
done
