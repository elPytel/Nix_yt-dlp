#!/usr/bin/env bash
# Convert downloaded audio files from the Makefile state queue.
# The worker waits for .done markers, skips unavailable .skipped items,
# converts one file at a time with ffmpeg, and marks it .converted.

set -u

MODE="podcast"
MANIFEST=".yt-dlp-items.tsv"
STATE=".yt-dlp-state"
STAGING="$STATE/downloads"
INTERVAL=1
TARGET=""

usage() {
    cat <<'EOF'
Usage: convert.sh [options]

Convert completed audio downloads from the yt-dlp queue.

Options:
  --mode MODE          podcast or audiobook (default: podcast)
  --manifest FILE      Manifest path (default: .yt-dlp-items.tsv)
  --state DIRECTORY    State directory (default: .yt-dlp-state)
  --staging DIRECTORY  Download staging directory
  --interval SECONDS   Queue polling interval (default: 1)
    --target TARGET      Process only one manifest target
  -h, --help           Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode)
            [[ $# -ge 2 ]] || { echo "Missing value for --mode" >&2; exit 2; }
            MODE="$2"
            shift 2
            ;;
        --manifest)
            [[ $# -ge 2 ]] || { echo "Missing value for --manifest" >&2; exit 2; }
            MANIFEST="$2"
            shift 2
            ;;
        --state)
            [[ $# -ge 2 ]] || { echo "Missing value for --state" >&2; exit 2; }
            STATE="$2"
            STAGING="$STATE/downloads"
            shift 2
            ;;
        --staging)
            [[ $# -ge 2 ]] || { echo "Missing value for --staging" >&2; exit 2; }
            STAGING="$2"
            shift 2
            ;;
        --interval)
            [[ $# -ge 2 ]] || { echo "Missing value for --interval" >&2; exit 2; }
            INTERVAL="$2"
            shift 2
            ;;
        --target)
            [[ $# -ge 2 ]] || { echo "Missing value for --target" >&2; exit 2; }
            TARGET="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
done

case "$MODE" in
    podcast|audiobook) ;;
    video) exit 0 ;;
    *)
        echo "Invalid mode: $MODE (use podcast or audiobook)" >&2
        exit 2
        ;;
esac

[[ -f "$MANIFEST" ]] || {
    echo "Manifest not found: $MANIFEST" >&2
    exit 1
}

mkdir -p "$STATE"

while :; do
    pending=0

    while IFS=$'\t' read -r target name index url; do
        [[ -n "$target" ]] || continue
        [[ -z "$TARGET" || "$target" == "$TARGET" ]] || continue

        done_marker="$STATE/$target.done"
        skipped_marker="$STATE/$target.skipped"
        converted_marker="$STATE/$target.converted"

        [[ -f "$skipped_marker" ]] && continue

        if [[ -f "$done_marker" && ! -f "$converted_marker" ]]; then
            source=$(find "$STAGING/$target" -type f -print -quit)
            if [[ -z "$source" ]]; then
                echo "Downloaded file missing: $target" >&2
                exit 1
            fi

            base=${source##*/}
            base=${base%.*}
            mkdir -p "$name"

            if [[ "$MODE" == "podcast" ]]; then
                output="$name/$(printf '%02d' "$index") - $base.m4a"
            else
                output="$name/$base.m4a"
            fi

            echo "Converting: $source -> $output"
            if ffmpeg -nostdin -y -i "$source" -map_metadata 0 -vn \
                -c:a aac -b:a 192k "$output"; then
                rm -rf "$STAGING/$target"
                touch "$converted_marker"
            else
                echo "Conversion failed: $target" >&2
                exit 1
            fi
        elif [[ ! -f "$converted_marker" ]]; then
            pending=1
        fi
    done < "$MANIFEST"

    [[ "$pending" -eq 0 ]] && break
    sleep "$INTERVAL"
done
