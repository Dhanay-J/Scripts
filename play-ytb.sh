#!/bin/bash

# play-ytb: A high-quality YouTube streaming script for Linux
# Uses yt-dlp for extraction and ffmpeg+VLC for playback.

set -e

# --- Configuration ---
DEFAULT_QUALITY="bestvideo[height<=720]+bestaudio/best"
SCRIPT_NAME=$(basename "$0")

# --- Functions ---

print_help() {
    echo "Usage: $SCRIPT_NAME [OPTIONS] [URL]"
    echo ""
    echo "Stream YouTube videos in high quality using VLC."
    echo ""
    echo "Options:"
    echo "  -h, --help     Show this help message"
    echo "  -q, --quality  Set quality (e.g., 'best', '1080p', '480p')"
    echo "                 Default: bestvideo[height<=720]+bestaudio/best"
    echo ""
    echo "Examples:"
    echo "  $SCRIPT_NAME https://youtu.be/example"
    echo "  $SCRIPT_NAME -q 1080p https://youtu.be/example"
}

check_dependencies() {
    local missing_deps=()
    
    # Check for required commands
    for cmd in yt-dlp ffmpeg vlc grep; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo "Error: Missing dependencies: ${missing_deps[*]}"
        read -p "Do you want to install them now? (y/n): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            echo "Installing dependencies..."
            sudo apt update
            sudo apt install -y "${missing_deps[@]}"
            
            # Special check for yt-dlp version after install
            if command -v yt-dlp &> /dev/null; then
                echo "Verifying yt-dlp installation..."
                # If it's an old apt version, we might need to warn or upgrade
                local ver=$(yt-dlp --version)
                echo "Installed yt-dlp version: $ver"
            fi
        else
            echo "Cannot proceed without dependencies. Exiting."
            exit 1
        fi
    fi
}

get_stream_urls() {
    local url="$1"
    local quality="$2"
    
    echo "Extracting stream information from YouTube..."
    
    # Extract Video URL
    V_URL=$(yt-dlp --remote-components ejs:github -g -f "$quality" "$url" 2>/dev/null | head -n 1)
    
    # Extract Audio URL (if the quality format didn't already include it)
    # If the format string contains '+', yt-dlp might return two lines. 
    # We handle this by checking if V_URL actually contains audio or if we need a separate A_URL.
    # For simplicity in the ffmpeg pipe, we'll try to get them separately if needed.
    
    if [[ "$quality" == *"+"* ]]; then
        # yt-dlp returns two lines: video then audio
        local urls=($(yt-dlp --remote-components ejs:github -g -f "$quality" "$url" 2>/dev/null))
        V_URL="${urls[0]}"
        A_URL="${urls[1]}"
    else
        # Fallback: get best audio separately if not included
        A_URL=$(yt-dlp --remote-components ejs:github -g -f 'bestaudio' "$url" 2>/dev/null | head -n 1)
    fi

    # Get User-Agent
    UA=$(yt-dlp --remote-components ejs:github --print "%(http_headers)s" "$url" 2>/dev/null | grep -oP '(?<=User-Agent: ).*' || echo "Mozilla/5.0")

    if [ -z "$V_URL" ]; then
        echo "Error: Could not extract video URL. YouTube may be blocking the request."
        exit 1
    fi
}

play_video() {
    local v_url="$1"
    local a_url="$2"
    local ua="$3"

    echo "Starting playback..."
    
    # Disable hardware acceleration in VLC via command line to prevent VM issues
    # --avcodec-hw=none disables HW decoding
    
    if [ -n "$a_url" ]; then
        # Merge video and audio using ffmpeg and pipe to VLC
        ffmpeg -reconnect 1 -reconnect_streamed 1 -reconnect_delay_max 5 \
               -headers "User-Agent: $ua" -i "$v_url" \
               -headers "User-Agent: $ua" -i "$a_url" \
               -c copy -f matroska - 2>/dev/null | vlc --avcodec-hw=none -
    else
        # Play video only (if no audio stream found)
        vlc --http-user-agent="$ua" --avcodec-hw=none "$v_url"
    fi
}

# --- Main Logic ---

# Parse Arguments
QUALITY="$DEFAULT_QUALITY"
URL=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -h|--help) print_help; exit 0 ;;
        -q|--quality) QUALITY="$2"; shift ;;
        *) URL="$1" ;;
    esac
    shift
done

# Check Dependencies
check_dependencies

# Get URL if not provided
if [ -z "$URL" ]; then
    echo "No URL provided."
    read -p "Enter YouTube URL: " URL
    if [ -z "$URL" ]; then
        print_help
        exit 1
    fi
fi

# Execute
get_stream_urls "$URL" "$QUALITY"
play_video "$V_URL" "$A_URL" "$UA"
