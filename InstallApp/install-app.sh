#!/bin/bash
# ============================================================================
# Desktop Installer - Install applications to ~/Apps with .desktop launchers
# Supports single executables and complex directory structures (IDEs, SDKs)
# ============================================================================

# ---------- Constants ----------
readonly APPS_BASE_DIR="$HOME/Apps"
readonly DESKTOP_DIR="$HOME/.local/share/applications"

# Freedesktop.org registered main categories
readonly -a CATEGORIES=(
    "AudioVideo" "Audio" "Video"
    "Development" "Education"
    "Game" "Graphics"
    "Network" "Office"
    "Science" "Settings"
    "System" "Utility"
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
select_install_type() {
    zenity --list \
        --title="Installation Type" \
        --text="What are you installing?" \
        --column="Type" --column="Description" \
        --width=400 --height=200 \
        "Single" "A single executable file (e.g., AppImage, script)" \
        "Directory" "A folder with structure (e.g., Android Studio, Qt)" \
        2>/dev/null
}

select_executable() {
    zenity --file-selection \
        --title="Select the executable application" \
        --filename="$HOME/" 2>/dev/null
}

select_directory() {
    zenity --file-selection \
        --title="Select Application Root Directory" \
        --directory \
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
    local args=()
    local cat
    for cat in "${CATEGORIES[@]}"; do
        args+=(FALSE "$cat")
    done

    # Pre-select Utility as default
    local i
    for i in "${!args[@]}"; do
        if [ "${args[$i]}" = "Utility" ] && [ "${args[$((i-1))]}" = "FALSE" ]; then
            args[$((i-1))]="TRUE"
            break
        fi
    done

    zenity --list \
        --title="Select Categories" \
        --text="Choose one or more categories:" \
        --checklist \
        --column="Select" --column="Category" \
        --width=380 --height=460 \
        --separator=";" \
        "${args[@]}" 2>/dev/null
}

# ---------- Helpers ----------
sanitize_name() {
    local name="$1"
    name="${name// /_}"
    name="${name//\//_}"
    echo "$name"
}

get_default_name() {
    local path="$1"
    basename "$path" | sed 's/\.[^.]*$//'
}

# Auto-detect executable inside a directory
find_executable_in_dir() {
    local dir="$1"
    
    # Common patterns for IDEs/Tools
    local candidates=(
        "$dir/bin/studio.sh"
        "$dir/bin/qtcreator"
        "$dir/bin/idea.sh"
        "$dir/bin/code"
        "$dir/AppRun"
    )
    
    for candidate in "${candidates[@]}"; do
        if [ -f "$candidate" ] && [ -x "$candidate" ]; then
            echo "$candidate"
            return 0
        fi
    done
    
    # Fallback: Find any executable in bin/
    if [ -d "$dir/bin" ]; then
        local exec_in_bin
        exec_in_bin=$(find "$dir/bin" -maxdepth 1 -type f -executable | head -n 1)
        if [ -n "$exec_in_bin" ]; then
            echo "$exec_in_bin"
            return 0
        fi
    fi
    
    return 1
}

# Auto-detect icon inside a directory
find_icon_in_dir() {
    local dir="$1"
    local candidates=(
        "$dir/bin/studio.png"
        "$dir/bin/studio.svg"
        "$dir/icon.png"
        "$dir/icon.svg"
    )
    
    for candidate in "${candidates[@]}"; do
        if [ -f "$candidate" ]; then
            echo "$candidate"
            return 0
        fi
    done
    return 1
}

# ---------- Confirmation ----------
confirm_install() {
    local app_name="$1" source_path="$2" icon_path="$3" app_dir="$4" categories="$5"
    local type_label="File"
    [ -d "$source_path" ] && type_label="Directory"

    ui_confirm \
        "<b>App Name:</b> $app_name
<b>Source ($type_label):</b> $source_path
<b>Icon:</b> $icon_path
<b>Categories:</b> ${categories:-<i>none</i>}
<b>Install to:</b> $app_dir
Proceed?" \
        "Confirm" 420 "Install" "Cancel"
}

handle_existing_dir() {
    local app_dir="$1"
    [ -d "$app_dir" ] || return 0
    ui_confirm "$app_dir already exists.
Overwrite?" "Overwrite?" 380 "Overwrite" "Cancel" || return 1
    rm -rf "$app_dir"
}

# ---------- File Operations ----------
copy_app_content() {
    local source_path="$1" icon_path="$2" app_dir="$3"
    
    mkdir -p "$app_dir" || {
        ui_error "Failed to create $app_dir"
        return 1
    }

    if [ -d "$source_path" ]; then
        # Copy entire directory structure preserving attributes
        cp -a "$source_path"/. "$app_dir"/ || {
            ui_error "Failed to copy directory contents."
            return 1
        }
        APP_INSTALL_TYPE="directory"
    else
        # Copy single file
        local app_filename
        app_filename=$(basename "$source_path")
        cp "$source_path" "$app_dir/$app_filename" || {
            ui_error "Failed to copy executable."
            return 1
        }
        chmod +x "$app_dir/$app_filename"
        APP_INSTALL_TYPE="single"
        APP_FILENAME="$app_filename"
    fi

    # Handle Icon
    local icon_filename
    icon_filename=$(basename "$icon_path")
    cp "$icon_path" "$app_dir/$icon_filename" || {
        ui_error "Failed to copy icon."
        return 1
    }
    ICON_FILENAME="$icon_filename"
    
    return 0
}

# ---------- Desktop Entry ----------
write_desktop_file() {
    local safe_name="$1" app_name="$2" app_dir="$3" exec_path="$4" \
          icon_filename="$5" categories="$6"

    local desktop_file="$DESKTOP_DIR/${safe_name}.desktop"
    mkdir -p "$DESKTOP_DIR"

    cat > "$desktop_file" <<EOF
[Desktop Entry]
Name=$app_name
Exec="$exec_path" %U
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

    # 1. Select Installation Type
    local install_type
    install_type=$(select_install_type)
    if [ -z "$install_type" ]; then return 1; fi

    local source_path=""
    local final_exec_path=""
    local icon_path=""
    local default_name=""

    if [ "$install_type" = "Directory" ]; then
        # --- Directory Mode ---
        source_path=$(select_directory)
        [ -z "$source_path" ] && return 1
        
        default_name=$(basename "$source_path")
        
        # Auto-detect executable
        final_exec_path=$(find_executable_in_dir "$source_path")
        if [ -z "$final_exec_path" ]; then
            ui_info "Could not auto-detect executable. Please select it manually."
            final_exec_path=$(zenity --file-selection --title="Select Executable" --filename="$source_path/")
            [ -z "$final_exec_path" ] && return 1
        fi

        # Auto-detect icon
        icon_path=$(find_icon_in_dir "$source_path")
        if [ -z "$icon_path" ]; then
            ui_info "Please select an icon."
            icon_path=$(select_icon)
            [ -z "$icon_path" ] && return 1
        fi

    else
        # --- Single File Mode ---
        source_path=$(select_executable)
        [ -z "$source_path" ] && return 1
        
        default_name=$(get_default_name "$source_path")
        final_exec_path="$source_path"
        
        ui_info "Please select an icon."
        icon_path=$(select_icon)
        [ -z "$icon_path" ] && return 1
    fi

    # 2. Ask for app name
    local app_name
    app_name=$(prompt_app_name "$default_name")
    if [ -z "$app_name" ]; then return 1; fi

    # 3. Select categories
    local categories
    categories=$(select_categories)
    [ -z "$categories" ] && categories="Utility"

    # 4. Compute install location
    local safe_name app_dir
    safe_name=$(sanitize_name "$app_name")
    app_dir="$APPS_BASE_DIR/$safe_name"

    # 5. Confirm summary
    confirm_install "$app_name" "$source_path" "$icon_path" "$app_dir" "$categories" || return 1

    # 6. Handle existing dir
    handle_existing_dir "$app_dir" || return 1

    # 7. Copy files
    APP_FILENAME=""
    ICON_FILENAME=""
    APP_INSTALL_TYPE=""
    
    copy_app_content "$source_path" "$icon_path" "$app_dir" || return 1

    # 8. Determine final Exec string for .desktop file
    local desktop_exec_path
    if [ "$APP_INSTALL_TYPE" = "directory" ]; then
        # Calculate relative path of the executable from the source root
        local rel_path_from_source="${final_exec_path#$source_path/}"
        desktop_exec_path="$app_dir/$rel_path_from_source"
    else
        desktop_exec_path="$app_dir/$APP_FILENAME"
    fi

    # 9. Write .desktop file
    local desktop_file
    desktop_file=$(write_desktop_file \
        "$safe_name" "$app_name" "$app_dir" \
        "$desktop_exec_path" "$ICON_FILENAME" "$categories")

    # 10. Refresh database
    refresh_desktop_database

    # 11. Success message
    ui_info \
        "<b>✓ $app_name installed!</b>
Location: $app_dir
Launcher: $desktop_file
Categories: $categories

You can now delete the source files from Downloads." \
        380 "Done"
    
    echo "✓ Installed $app_name at $app_dir"
}

install "$@"
