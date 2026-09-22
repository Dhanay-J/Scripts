#!/bin/bash

# ============================================================================
# Desktop Installer - Install applications to ~/Apps with .desktop launchers
# ============================================================================

# ---------- Constants ----------
readonly APPS_BASE_DIR="$HOME/Apps"
readonly DESKTOP_DIR="$HOME/.local/share/applications"

# Freedesktop.org registered main categories (alphabetical)
readonly -a CATEGORIES=(
    "AudioVideo"
    "Audio"
    "Video"
    "Development"
    "Education"
    "Game"
    "Graphics"
    "Network"
    "Office"
    "Science"
    "Settings"
    "System"
    "Utility"
)

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

# ---------- Selection Prompts ----------
select_executable() {
    zenity --file-selection \
        --title="Select the executable application" \
        --filename="$HOME/" 2>/dev/null
}

select_icon() {
    zenity --file-selection \
        --title="Select an icon (png/svg/jpg)" \
        --file-filter="Images | *.png *.svg *.jpg *.jpeg *.xpm" \
        --filename="$HOME/" 2>/dev/null
}

prompt_app_name() {
    local default_name="$1"
    zenity --entry \
        --title="App Name" \
        --text="Enter a name for the application:" \
        --entry-text="$default_name" 2>/dev/null
}

# ---------- Category Selection ----------
select_categories() {
    # Build column list for zenity --list with checkboxes
    local args=()
    local cat
    for cat in "${CATEGORIES[@]}"; do
        args+=(FALSE "$cat")
    done

    # Pre-select Utility as a sensible default
    # (replace the FALSE preceding "Utility" with TRUE)
    local i
    for i in "${!args[@]}"; do
        if [ "${args[$i]}" = "Utility" ] && [ "${args[$((i-1))]}" = "FALSE" ]; then
            args[$((i-1))]="TRUE"
            break
        fi
    done

    zenity --list \
        --title="Select Categories" \
        --text="Choose one or more categories for the application menu:" \
        --checklist \
        --column="Select" --column="Category" \
        --width=380 --height=460 \
        --separator=";" \
        "${args[@]}" 2>/dev/null
}

# ---------- Helpers ----------
sanitize_name() {
    # Replace spaces with underscores; strip path separators
    local name="$1"
    name="${name// /_}"
    name="${name//\//_}"
    echo "$name"
}

default_name_from_path() {
    basename "$1" | sed 's/\.[^.]*$//'
}

# ---------- Confirmation ----------
confirm_install() {
    local app_name="$1" app_path="$2" icon_path="$3" app_dir="$4" categories="$5"
    ui_confirm \
        "<b>App Name:</b> $app_name
<b>Executable:</b> $app_path
<b>Icon:</b> $icon_path
<b>Categories:</b> ${categories:-<i>none</i>}
<b>Install to:</b> $app_dir

Proceed?" \
        "Confirm" 420 "Install" "Cancel"
}

handle_existing_dir() {
    local app_dir="$1"
    [ -d "$app_dir" ] || return 0

    ui_confirm "$app_dir already exists.\nOverwrite?" "Overwrite?" 380 "Overwrite" "Cancel" || return 1
    rm -rf "$app_dir"
}

# ---------- File Operations ----------
copy_app_files() {
    local app_path="$1" icon_path="$2" app_dir="$3"
    local app_filename icon_filename

    app_filename=$(basename "$app_path")
    icon_filename=$(basename "$icon_path")

    mkdir -p "$app_dir" || {
        ui_error "Failed to create $app_dir"
        return 1
    }

    cp "$app_path" "$app_dir/$app_filename" || {
        ui_error "Failed to copy executable."
        return 1
    }

    cp "$icon_path" "$app_dir/$icon_filename" || {
        ui_error "Failed to copy icon."
        return 1
    }

    chmod +x "$app_dir/$app_filename"

    # Export for caller
    APP_FILENAME="$app_filename"
    ICON_FILENAME="$icon_filename"
    return 0
}

# ---------- Desktop Entry ----------
write_desktop_file() {
    local safe_name="$1" app_name="$2" app_dir="$3" app_filename="$4" \
          icon_filename="$5" categories="$6"
    local desktop_file="$DESKTOP_DIR/${safe_name}.desktop"

    mkdir -p "$DESKTOP_DIR"

    cat > "$desktop_file" <<EOF
[Desktop Entry]
Name=$app_name
Exec="$app_dir/$app_filename" %U
Icon=$app_dir/$icon_filename
Terminal=false
Type=Application
StartupNotify=true
Categories=${categories};
EOF

    chmod +x "$desktop_file"
    echo "$desktop_file"
}

refresh_desktop_database() {
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$DESKTOP_DIR" 2>/dev/null
    fi
}

# ---------- Main Flow ----------
install() {
    check_dependencies || return 1

    # 1. Select executable
    local app_path
    app_path=$(select_executable)
    if [ -z "$app_path" ]; then
        echo "Cancelled: no executable selected."
        return 1
    fi

    # 2. Select icon
    local icon_path
    icon_path=$(select_icon)
    if [ -z "$icon_path" ]; then
        echo "Cancelled: no icon selected."
        return 1
    fi

    # 3. Ask for app name
    local default_name app_name
    default_name=$(default_name_from_path "$app_path")
    app_name=$(prompt_app_name "$default_name")
    if [ -z "$app_name" ]; then
        echo "Cancelled: no app name entered."
        return 1
    fi

    # 4. Select categories
    local categories
    categories=$(select_categories)
    if [ -z "$categories" ]; then
        # User cancelled or selected nothing — fall back to Utility
        categories="Utility"
        echo "No categories selected; defaulting to Utility."
    else
        # zenity returns values separated by ';' — already suitable for .desktop
        :
    fi

    # 5. Compute install location
    local safe_name app_dir
    safe_name=$(sanitize_name "$app_name")
    app_dir="$APPS_BASE_DIR/$safe_name"

    # 6. Confirm summary
    confirm_install "$app_name" "$app_path" "$icon_path" "$app_dir" "$categories" || {
        echo "Cancelled by user."
        return 1
    }

    # 7. Handle existing dir
    handle_existing_dir "$app_dir" || {
        echo "Aborted."
        return 1
    }

    # 8. Copy files
    APP_FILENAME=""
    ICON_FILENAME=""
    copy_app_files "$app_path" "$icon_path" "$app_dir" || return 1

    # 9. Write .desktop file
    local desktop_file
    desktop_file=$(write_desktop_file \
        "$safe_name" "$app_name" "$app_dir" \
        "$APP_FILENAME" "$ICON_FILENAME" "$categories")

    # 10. Refresh database
    refresh_desktop_database

    # 11. Success message
    ui_info \
        "<b>✓ $app_name installed!</b>

Location: $app_dir
Launcher: $desktop_file
Categories: $categories

You can now launch it from your app menu." \
        380 "Done"

    echo "✓ Installed $app_name at $app_dir"
}

install "$@"

