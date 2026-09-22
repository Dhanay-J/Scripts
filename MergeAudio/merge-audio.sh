#!/usr/bin/env bash
# ============================================================
#  merge-audio.sh — Single-form GUI for ffmpeg
#  File pickers for video/audio, single-window settings form.
#  Requires: ffmpeg, zenity, progress  (optionally: yad)
# ============================================================
set -u

# ---------- Globals ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="./config.conf"
[ -f "$CONFIG_FILE" ] || CONFIG_FILE="$SCRIPT_DIR/config.conf"

VIDEO=""
AUDIO=""
OUTPUT=""
LOG=""
FFPID=""

KEEP_BOTH="false"
LOG_PATH="auto"
AUTO_REMOVE_INPUTS="false"
LAST_DIR="$HOME"

HAS_YAD="false"
command -v yad >/dev/null 2>&1 && HAS_YAD="true"

# ============================================================
# Config I/O
# ============================================================

load_config() {
    [ -f "$CONFIG_FILE" ] || return 0

    while IFS='=' read -r key value || [[ -n "$key" ]]; do
        key="${key#"${key%%[![:space:]]*}"}"; key="${key%"${key##*[![:space:]]}"}"
        value="${value#"${value%%[![:space:]]*}"}"; value="${value%"${value##*[![:space:]]}"}"
        [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue

        value="${value#\"}"; value="${value%\"}"
        value="${value#\'}"; value="${value%\'}"

        case "$key" in
            KEEP_BOTH|AUTO_REMOVE_INPUTS)
                [[ "$value" =~ ^(true|yes|1)$ ]] && value="true" || value="false"
                ;;
        esac
        declare -g "$key=$value"
    done < "$CONFIG_FILE"

    KEEP_BOTH="${KEEP_BOTH:-false}"
    LOG_PATH="${LOG_PATH:-auto}"
    AUTO_REMOVE_INPUTS="${AUTO_REMOVE_INPUTS:-false}"
}

save_config() {
    local kb="$KEEP_BOTH" ari="$AUTO_REMOVE_INPUTS"
    [[ "$kb"  =~ ^(true|yes|1)$ ]] && kb="true"  || kb="false"
    [[ "$ari" =~ ^(true|yes|1)$ ]] && ari="true" || ari="false"

    cat > "$CONFIG_FILE" <<EOF
# merge-audio.sh configuration
KEEP_BOTH=$kb
LOG_PATH=$LOG_PATH
AUTO_REMOVE_INPUTS=$ari
EOF
}

# ============================================================
# Utility
# ============================================================

die() {
    zenity --error --width=350 --title="Error" --text="$1" 2>/dev/null
    exit 1
}

check_dependencies() {
    for cmd in ffmpeg zenity progress; do
        command -v "$cmd" >/dev/null 2>&1 || die "'$cmd' is not installed!"
    done
}

# ============================================================
# Single-Form UI — yad version (file pickers)
# ============================================================

show_form_yad() {
    local result
    result=$(yad --form \
        --title="Merge Audio into Video" \
        --width=720 --height=340 \
        --borders=12 \
        --text="<b>Configure the merge.</b>  Settings are saved on OK." \
        --separator="|" \
        --field="Video file:FL" \
        --field="Audio file:FL" \
        --field="Output file:SAVE" \
        --field="Keep original audio:CHK" \
        --field="Log path" \
        --field="Auto-remove inputs:CHK" \
        "$VIDEO" \
        "$AUDIO" \
        "$OUTPUT" \
        "$([[ "$KEEP_BOTH" = "true" ]] && echo TRUE || echo FALSE)" \
        "$LOG_PATH" \
        "$([[ "$AUTO_REMOVE_INPUTS" = "true" ]] && echo TRUE || echo FALSE)") || return 1

    # yad pipes with --separator="|"
    IFS='|' read -r FORM_VIDEO FORM_AUDIO FORM_OUTPUT FORM_KEEP_BOTH FORM_LOG_PATH FORM_AUTO_REMOVE <<< "$result"

    # Normalize yad booleans (TRUE/FALSE) to our true/false
    case "${FORM_KEEP_BOTH^^}" in TRUE|YES|1) FORM_KEEP_BOTH="true" ;; *) FORM_KEEP_BOTH="false" ;; esac
    case "${FORM_AUTO_REMOVE^^}" in TRUE|YES|1) FORM_AUTO_REMOVE="true" ;; *) FORM_AUTO_REMOVE="false" ;; esac
}

# ============================================================
# Single-Form UI — zenity fallback (typed paths, no picker)
# ============================================================

show_form_zenity() {
    local result
    result=$(zenity --forms \
        --title="Merge Audio into Video" \
        --width=620 \
        --text="Configure the merge. Settings are saved to config.conf on OK." \
        --add-entry="Video file (full path)" \
        --add-entry="Audio file (full path)" \
        --add-entry="Output file (.mp4)" \
        --add-combo="Keep original audio too?" \
            --combo-values="false|true" \
        --add-combo="Log path" \
            --combo-values="auto|$HOME/ffmerge.log" \
        --add-combo="Auto-remove inputs after success?" \
            --combo-values="false|true") || return 1

    FORM_VIDEO=$(echo "$result" | sed -n '1p')
    FORM_AUDIO=$(echo "$result" | sed -n '2p')
    FORM_OUTPUT=$(echo "$result" | sed -n '3p')
    FORM_KEEP_BOTH=$(echo "$result" | sed -n '4p')
    FORM_LOG_PATH=$(echo "$result" | sed -n '5p')
    FORM_AUTO_REMOVE=$(echo "$result" | sed -n '6p')
}

# Dispatch to whichever backend is available
show_main_form() {
    if [ "$HAS_YAD" = "true" ]; then
        show_form_yad
    else
        show_form_zenity
    fi
}

# ============================================================
# Validation & Defaults
# ============================================================

apply_form_values() {
    VIDEO="$FORM_VIDEO"
    AUDIO="$FORM_AUDIO"

    [ -n "$VIDEO" ] && [ -f "$VIDEO" ] || return 2
    [ -n "$AUDIO" ] && [ -f "$AUDIO" ] || return 2

    if [ -z "$FORM_OUTPUT" ]; then
        local dir stem
        dir=$(dirname "$VIDEO")
        stem=$(basename "$VIDEO"); stem="${stem%.*}"
        FORM_OUTPUT="$dir/${stem}_merged.mp4"
    fi
    case "$FORM_OUTPUT" in
        *.mp4) ;;
        *) FORM_OUTPUT="${FORM_OUTPUT}.mp4" ;;
    esac
    OUTPUT="$FORM_OUTPUT"

    KEEP_BOTH="$FORM_KEEP_BOTH"
    LOG_PATH="${FORM_LOG_PATH:-auto}"
    AUTO_REMOVE_INPUTS="$FORM_AUTO_REMOVE"

    # Remember last-used folder for next run
    LAST_DIR="$(dirname "$VIDEO")"
}

# ============================================================
# Log / ffmpeg
# ============================================================

setup_log() {
    if [ "$LOG_PATH" = "auto" ]; then
        LOG=$(mktemp /tmp/ffmerge.XXXXXX.log)
    else
        mkdir -p "$(dirname "$LOG_PATH")" 2>/dev/null
        LOG="$LOG_PATH"
    fi
}

build_map_args() {
    if [ "$KEEP_BOTH" = "true" ]; then
        MAP=(-map 0:v:0 -map 0:a:0 -map 1:a:0)
    else
        MAP=(-map 0:v:0 -map 1:a:0)
    fi
}

run_ffmpeg_with_progress() {
    local title
    title="$(basename "$OUTPUT")"

    ffmpeg -hide_banner -y \
      -i "$VIDEO" -i "$AUDIO" \
      "${MAP[@]}" \
      -c:v copy -c:a aac \
      -shortest \
      "$OUTPUT" 2>"$LOG" &
    FFPID=$!

    sleep 1

    (
        while kill -0 "$FFPID" 2>/dev/null; do
            PCT=$(progress -q -c ffmpeg 2>/dev/null | awk '
                /%/ {
                    match($0, /[0-9.]+(%)/);
                    if (RLENGTH > 0) {
                        print substr($0, RSTART, RLENGTH-1);
                        exit;
                    }
                }
            ')
            if [ -n "$PCT" ]; then
                echo "$PCT"
                echo "# Merging audio... ($PCT%)"
            else
                echo "# Merging audio... (starting...)"
            fi
            sleep 0.5
        done
        echo "100"
    ) | zenity --progress --width=420 --title="Merging audio..." \
        --text="$title" --auto-close --no-cancel --percentage=0 2>/dev/null

    wait "$FFPID"
    return $?
}

# ============================================================
# Reporting
# ============================================================

handle_success() {
    [ "$LOG_PATH" = "auto" ] && rm -f "$LOG"
    if [ "$AUTO_REMOVE_INPUTS" = "true" ]; then
        rm -f "$VIDEO" "$AUDIO"
    fi
    # Silent success — closing progress bar is the confirmation.
}

handle_failure() {
    local rc="$1"
    local logtail=""
    [ -f "$LOG" ] && logtail="$(tail -n 15 "$LOG")"

    zenity --error --width=560 --title="FFmpeg failed" \
      --text="FFmpeg exited with code $rc.

Last output lines:
$logtail"
    [ "$LOG_PATH" = "auto" ] && rm -f "$LOG"
    exit 1
}

# ============================================================
# Main
# ============================================================

main() {
    check_dependencies
    load_config

    # Pre-populate with config / last-used values
    VIDEO=""
    AUDIO=""
    OUTPUT=""

    while true; do
        show_main_form || exit 0

        if ! apply_form_values; then
            zenity --warning --width=400 --title="Missing files" \
              --text="Please provide valid paths for both video and audio files." \
              2>/dev/null
            # Keep whatever the user typed so they can fix just one field
            VIDEO="$FORM_VIDEO"
            AUDIO="$FORM_AUDIO"
            continue
        fi
        break
    done

    save_config

    build_map_args
    setup_log

    if run_ffmpeg_with_progress; then
        handle_success
    else
        handle_failure $?
    fi
}

main "$@"