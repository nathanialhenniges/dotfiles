#!/bin/bash
set -euo pipefail

script="$(cd "$(dirname "$0")/.." && pwd)/config/.scripts/yt-video-backup"
fixture=$(mktemp -d)
trap 'rm -rf "$fixture"' EXIT

home="$fixture/home"
drive="$fixture/GoogleDrive-test"
source="$home/Movies/Final Cut Projects/YouTube/2026/2026-11-03-test video"
destination="$drive/My Drive/MultiMedia Projects/Social Media/YouTube/Editing/2026/2026-11-03-test video"
mkdir -p "$source/Publish" "$drive/My Drive/MultiMedia Projects/Social Media/YouTube"
printf 'test video bytes\n' > "$source/Publish/test.mp4"

if env -u MEDIA_BACKUP_DRIVE HOME="$home" "$script" '2026/2026-11-03-test video' >/dev/null 2>&1; then
  echo 'Missing private Drive variable was accepted.' >&2
  exit 1
fi

env HOME="$home" MEDIA_BACKUP_DRIVE="$drive" "$script" '2026/2026-11-03-test video' >/dev/null
cmp "$source/Publish/test.mp4" "$destination/Publish/test.mp4"

printf 'keep this backup\n' > "$destination/Publish/test.mp4"
if env HOME="$home" MEDIA_BACKUP_DRIVE="$drive" "$script" '2026/2026-11-03-test video' >/dev/null 2>&1; then
  echo 'Existing backup was overwritten.' >&2
  exit 1
fi
grep -qx 'keep this backup' "$destination/Publish/test.mp4"

if env HOME="$home" MEDIA_BACKUP_DRIVE="$drive" "$script" "$fixture/outside" >/dev/null 2>&1; then
  echo 'Outside project folder was accepted.' >&2
  exit 1
fi

corrupt_source="$home/Movies/Final Cut Projects/YouTube/2026/2026-11-03-corrupt"
mkdir -p "$corrupt_source/Publish" "$fixture/bin"
printf 'original\n' > "$corrupt_source/Publish/test.mp4"
cat > "$fixture/bin/ditto" <<'EOF'
#!/bin/bash
/usr/bin/ditto "$@"
printf 'corrupted\n' > "$2/Publish/test.mp4"
EOF
chmod +x "$fixture/bin/ditto"
if env PATH="$fixture/bin:$PATH" HOME="$home" MEDIA_BACKUP_DRIVE="$drive" \
  "$script" '2026/2026-11-03-corrupt' >/dev/null 2>&1; then
  echo 'Corrupt copy was accepted.' >&2
  exit 1
fi
test ! -e "$drive/My Drive/MultiMedia Projects/Social Media/YouTube/Editing/2026/2026-11-03-corrupt"

echo 'yt-video-backup: copy, verification, and safety checks passed'
