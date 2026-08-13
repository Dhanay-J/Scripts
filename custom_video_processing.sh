#!/bin/bash
# HandBrake

HANDBRAKE="HandBrakeCLI"
INPUT_DIR="."
OUTPUT_DIR="./proceseed"

if ! command -v "$HANDBRAKE" &>/dev/null; then
    echo "ERROR: HandBrakeCLI not found"; exit 1
fi
mkdir -p "$OUTPUT_DIR"

shopt -s nullglob nocaseglob
files=( *.mp4 *.mkv *.avi *.mov *.m4v *.wmv *.flv )
shopt -u nullglob nocaseglob

if [ ${#files[@]} -eq 0 ]; then
    echo "No video files found in $(pwd)"; exit 0
fi

echo "Found ${#files[@]} file(s) | Encoder: NVENC RTX 3050 | Output: $(realpath "$OUTPUT_DIR")"
echo "======================================================================"

success=0; failed=0
for i in "${!files[@]}"; do
    file="${files[$i]}"
    filename=$(basename "${file%.*}")
    outfile="$OUTPUT_DIR/${filename}.mkv"

    echo ""
    echo "▶ [$((i+1))/${#files[@]}] $file"

    "$HANDBRAKE" \
        -i "$file" \
        -o "$outfile" \
        -e nvenc_h264 \
        --encoder-preset medium \
        -q 24 \
        --width 1280 --height 720 \
        --keep-display-aspect \
        --auto-anamorphic \
        --rate auto \
        --audio 2 \
        -E copy:aac \
        --audio-fallback av_aac \
        --ab 160 \
        --subtitle scan \
        --all-subtitles \
        --subtitle-default none \
        -f av_mkv

    if [ $? -eq 0 ]; then
        echo "  ✔ Done: ${filename}.mkv"; ((success++))
    else
        echo "  ✘ FAILED: $file"; ((failed++))
    fi
done

echo ""
echo "======================================================================"
[ $failed -gt 0 ] && echo "Complete: $success ok, $failed failed / ${#files[@]}" \
                  || echo "Complete: All $success files converted!"
