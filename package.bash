#!/usr/bin/env bash
set -euo pipefail
hash python3 zip ffdec
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

swf="${@:-homerunderby_en.swf}"
if [[ ! -f "$swf" ]]; then
  printf -- '%s: file not found: %s\n' "$0" "$swf" 1>&2
  exit 1
fi

expected_sha256=a083b6278f3ad7c7dc69559837144e1b27a5748078862fc28882eb61763f03b3
read -r given_sha256 _ < <(sha256sum -b "$swf")
if [[ "$given_sha256" != "$expected_sha256" ]]; then
  printf -- '%s: sha256 mismatch: %s != %s\n' "$0" "$given_sha256" "$expected_sha256" 1>&2
  exit 1
fi

ffdec -importScript "$swf" "$tmpdir/patched.swf" ./src

python3 <<EOF
import bsdiff4

with open("$swf", "rb") as f:
    vanilla = f.read()
with open("$tmpdir/patched.swf", "rb") as f:
    patched = f.read()

patch_bytes = bsdiff4.diff(vanilla, patched)
with open("apworld/data/patch.bsdiff4", "wb") as f:
    f.write(patch_bytes)
EOF

rm -rf apworld/__pycache__
ln -s "$PWD/apworld" "$tmpdir/winnie_the_pooh_hrd"
dest="$PWD/winnie_the_pooh_hrd.apworld"
(cd "$tmpdir" && zip -r "$dest" winnie_the_pooh_hrd)
