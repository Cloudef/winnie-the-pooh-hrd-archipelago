#!/usr/bin/env bash
set -euo pipefail
hash python3

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

cat > "$tmpdir/player.yaml" << EOF
name: TestPlayer
game: Winnie the Pooh's Home Run Derby
Winnie the Pooh's Home Run Derby:
  shuffle_stages: true
  start_inventory: {Eeyore: 1}
  death_link: true
EOF

cat > "$tmpdir/player2.yaml" << EOF
name: TestPlayer2
game: Winnie the Pooh's Home Run Derby
Winnie the Pooh's Home Run Derby:
  shuffle_stages: true
  start_inventory: {Eeyore: 1}
  death_link: true
EOF

rm -f Archipelago/worlds/winnie_the_pooh_hrd
ln -s "$PWD/apworld" Archipelago/worlds/winnie_the_pooh_hrd
(cd Archipelago && python3 Generate.py --player_files_path "$tmpdir" --outputpath "$tmpdir")
printf -- 'run: python3 apworld/client.py --nogui --connect localhost:38281\n'
(cd Archipelago && python3 MultiServer.py "$tmpdir"/AP_*.zip)
