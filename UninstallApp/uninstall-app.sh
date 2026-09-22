#!/bin/bash

# ============================================================================
# Desktop Uninstaller - Remove apps installed by the installer script
# ============================================================================

# ---------- Constants ----------
readonly APPS_BASE_DIR="$HOME/Apps"
readonly DESKTOP_DIR="$HOME/.local/share/applications"

# ---------- UI Helpers ----------
ui_error() {
    zenity --error --text="$1" 2>/dev/null
}

ui_info() {
    zenity --info --width="${2:-380}" --title="${3:-Info}" --text="$1" 2>/dev/null
}

ui_confirm() {
    zenity --question --title="${2:-Confirm}" --width="${3:-420}" \
        --text="$1" \
        --ok-label="${4:-OK}" --cancel-label="${5:-Cancel}" 2>/dev/null
}

# ---------- Dependency Check ----------
check_dependencies() {
    if ! command -v zenity >/dev/null 2>&1; then
        echo "Error: zenity is not installed. Install with: sudo apt install zenity" >&2
        return 1
    fi
    return 0
}

# ---------- Discovery ----------
# List installed app directory names under $APPS_BASE_DIR.
list_installed_apps() {
    [ -d "$APPS_BASE_DIR" ] || return 0

    local dir
    for dir in "$APPS_BASE_DIR"/*/; do
        [ -d "$dir" ] || continue
        basename "$dir"
    done
}

# Find the .desktop file associated with an app (by sanitized name).
find_desktop_file() {
    local safe_name="$1"
    local candidate="$DESKTOP_DIR/${safe_name}.desktop"
    [ -f "$candidate" ] && echo "$candidate"
}

# Read a field value from the .desktop file (first match).
read_desktop_field() {
    local desktop_file="$1" field="$2"
    [ -f "$desktop_file" ] || return 1
    grep -m1 "^${field}=" "$desktop_file" | cut -d'=' -f2-
}

# ---------- Selection ----------
select_app_to_uninstall() {
    local -a apps=("$@")

    if [ ${#apps[@]} -eq 0 ]; then
        return 1
    fi

    # Build display rows: sanitized name -> pretty name (from .desktop if present)
    local -a rows=()
    local safe_name pretty_name desktop_file
    for safe_name in "${apps[@]}"; do
        desktop_file=$(find_desktop_file "$safe_name")
        if [ -n "$desktop_file" ]; then
            pretty_name=$(read_desktop_field "$desktop_file" "Name")
        fi
        [ -z "$pretty_name" ] && pretty_name="$safe_name"

        rows+=("$safe_name" "$pretty_name")
    done

    zenity --list \
        --title="Uninstall Application" \
        --text="Select an application to uninstall:" \
        --column="ID" --column="Name" \
        --width=480 --height=400 \
        --hide-column=1 \
        --print-column=1 \
        "${rows[@]}" 2>/dev/null
}

# ---------- Removal ----------
# Confirm the uninstall and show what will be removed.
confirm_uninstall() {
    local safe_name="$1"
    local app_dir="$APPS_BASE_DIR/$safe_name"
    local desktop_file
    desktop_file=$(find_desktop_file "$safe_name")

    local pretty_name="$safe_name"
    [ -n "$desktop_file" ] && pretty_name=$(read_desktop_field "$desktop_file" "Name")

    local desktop_display="${desktop_file:-<i>none found</i>}"

    ui_confirm \
        "<b>Uninstall:</b> $pretty_name

<b>App directory:</b> $app_dir
<b>Launcher:</b> $desktop_display

This will permanently delete the above.
Proceed?" \
        "Confirm Uninstall" 440 "Uninstall" "Cancel"
}

# Remove the .desktop launcher, if any.
remove_desktop_file() {
    local safe_name="$1"
    local desktop_file
    desktop_file=$(find_desktop_file "$safe_name")

    [ -z "$desktop_file" ] && return 0

    rm -f "$desktop_file" || return 1
    return 0
}

# Remove the app directory.
remove_app_dir() {
    local safe_name="$1"
    local app_dir="$APPS_BASE_DIR/$safe_name"

    [ -d "$app_dir" ] || return 0

    rm -rf "$app_dir" || return 1
    return 0
}

# ---------- Cache refresh ----------
refresh_desktop_database() {
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$DESKTOP_DIR" 2>/dev/null
    fi
}

# ---------- Main Flow ----------
uninstall() {
    check_dependencies || return 1

    # Collect installed apps
    local -a apps=()
    while IFS= read -r line; do
        [ -n "$line" ] && apps+=("$line")
    done < <(list_installed_apps)

    if [ ${#apps[@]} -eq 0 ]; then
        ui_info "No applications found in:\n$APPS_BASE_DIR" 380 "Nothing to uninstall"
        echo "No apps installed under $APPS_BASE_DIR"
        return 0
    fi

    # Prompt user for the app to remove
    local safe_name
    safe_name=$(select_app_to_uninstall "${apps[@]}")
    if [ -z "$safe_name" ]; then
        echo "Cancelled: no app selected."
        return 1
    fi

    # Guard against path traversal / unexpected input
    if [[ "$safe_name" == */* || "$safe_name" == "." || "$safe_name" == ".." ]]; then
        ui_error "Invalid application identifier: $safe_name"
        return 1
    fi

    # Confirm
    confirm_uninstall "$safe_name" || {
        echo "Cancelled by user."
        return 1
    }

    # Remove launcher, then directory
    if ! remove_desktop_file "$safe_name"; then
        ui_error "Failed to remove desktop launcher."
        return 1
    fi

    if ! remove_app_dir "$safe_name"; then
        ui_error "Failed to remove app directory."
        return 1
    fi

    refresh_desktop_database

    ui_info \
        "<b>✓ $safe_name uninstalled.</b>

Removed:
• $APPS_BASE_DIR/$safe_name
• $DESKTOP_DIR/${safe_name}.desktop" \
        400 "Done"

    echo "✓ Uninstalled $safe_name"
}

uninstall "$@"