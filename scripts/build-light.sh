#!/usr/bin/env bash
# Build Hermes Light (the remote-only desktop client) for an upstream release
# tag whose patches are already committed on top of it.
#
#   build-light.sh <hermes-checkout> <vX.Y.Z>
#
# Produces apps/desktop/release/HermesLight-X.Y.Z-<os>-<arch>.{AppImage,dmg,zip}.
#
# It packages as the stable tag, not as a commit build: a commit build names
# the app "Hermes Light <sha>" with its own app id and data directory, so every
# release would start from an empty profile. The upstream stable path wants a
# release claim (an annotated rc.<N>-vX.Y.Z tag on the admitted commit, as
# scripts/build-bundle.ps1 -Store makes locally); this script makes one for
# the patched commit and deletes it afterwards. Nothing is signed or notarized.
set -euo pipefail

src="$(cd "${1:?usage: build-light.sh <hermes-checkout> <vX.Y.Z>}" && pwd)"
tag="${2:?usage: build-light.sh <hermes-checkout> <vX.Y.Z>}"
[[ "$tag" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "build-light: $tag is not a stable vX.Y.Z tag" >&2; exit 2; }
version="${tag#v}"

cd "$src"
if [ -n "$(git status --porcelain --untracked-files=all)" ]; then
  echo "build-light: $src has uncommitted changes; the build packages HEAD" >&2
  git status --short --untracked-files=all >&2
  exit 1
fi

python=
for candidate in python3 python; do
  if command -v "$candidate" >/dev/null 2>&1 &&
     "$candidate" -c 'import sys; sys.exit(sys.version_info < (3, 11))' 2>/dev/null; then
    python="$candidate"; break
  fi
done
[ -n "$python" ] || { echo "build-light: needs Python 3.11+ on PATH" >&2; exit 1; }

sha="$(git rev-parse HEAD)"
claim="rc.900-v$version"
git tag -d "$claim" >/dev/null 2>&1 || true
git -c user.name=hermes-light-build -c user.email=light-build@invalid -c tag.gpgSign=false \
  tag -a "$claim" -m 'local light build claim' "$sha"
trap 'git tag -d "$claim" >/dev/null 2>&1 || true' EXIT

export RELEASE_CLAIM_TAG="$claim"
RELEASE_CLAIM_OBJECT="$(git rev-parse "refs/tags/$claim")"
export RELEASE_CLAIM_OBJECT
export PYTHONUTF8=1
# Never sign with whatever identity the host happens to have.
unset APPLE_API_KEY APPLE_API_KEY_ID APPLE_API_ISSUER APPLE_NOTARY_PROFILE APPLE_SIGNING_IDENTITY \
      CSC_LINK CSC_KEY_PASSWORD CSC_NAME CSC_KEYCHAIN CLOUDFLARE_R2_PUBLIC_URL
export CSC_IDENTITY_AUTO_DISCOVERY=false

echo "build-light: building $sha as Hermes Light $tag"
"$python" scripts/bundles/desktop.py --tag "$tag" --release-commit "$sha" --variant light --clean

echo "build-light: artifacts in $src/apps/desktop/release:"
find apps/desktop/release -maxdepth 1 -type f -name 'HermesLight-*' -exec ls -lh {} + | sed 's/^/  /'
