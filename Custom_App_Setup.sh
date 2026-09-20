create-app() {
    # --- Check zenity is installed ---
    if ! command -v zenity >/dev/null 2>&1; then
        echo "Error: zenity is not installed. Install with: sudo apt install zenity"
        return 1
    fi

    # --- 1. Select the executable ---
    local APP_PATH
    APP_PATH=$(zenity --file-selection \
        --title="Select the executable application" \
        --filename="$HOME/" 2>/dev/null)

    if [ -z "$APP_PATH" ]; then
        echo "Cancelled: no executable selected."
        return 1
    fi

    # --- 2. Select the icon ---
    local ICON_PATH
    ICON_PATH=$(zenity --file-selection \
        --title="Select an icon (png/svg/jpg)" \
        --file-filter="Images | *.png *.svg *.jpg *.jpeg *.xpm" \
        --filename="$HOME/" 2>/dev/null)

    if [ -z "$ICON_PATH" ]; then
        echo "Cancelled: no icon selected."
        return 1
    fi

    # --- 3. Ask for the app name (pre-filled from executable) ---
    local DEFAULT_NAME
    DEFAULT_NAME=$(basename "$APP_PATH" | sed 's/\.[^.]*$//')  # strip extension

    local APP_NAME
    APP_NAME=$(zenity --entry \
        --title="App Name" \
        --text="Enter a name for the application:" \
        --entry-text="$DEFAULT_NAME" 2>/dev/null)

    if [ -z "$APP_NAME" ]; then
        echo "Cancelled: no app name entered."
        return 1
    fi

    # Sanitize name for filesystem safety (no slashes/spaces replaced optional)
    local SAFE_NAME="${APP_NAME// /_}"
    local APP_DIR="$HOME/Apps/$SAFE_NAME"

    # --- 4. Confirm summary ---
    zenity --question \
        --title="Confirm" \
        --width=420 \
        --text="<b>App Name:</b> $APP_NAME\n<b>Executable:</b> $APP_PATH\n<b>Icon:</b> $ICON_PATH\n<b>Install to:</b> $APP_DIR\n\nProceed?" \
        --ok-label="Install" --cancel-label="Cancel" || {
        echo "Cancelled by user."
        return 1
    }

    # --- 5. Handle existing dir ---
    if [ -d "$APP_DIR" ]; then
        zenity --question --title="Overwrite?" \
            --text="$APP_DIR already exists.\nOverwrite?" \
            --ok-label="Overwrite" --cancel-label="Cancel" || {
            echo "Aborted."
            return 1
        }
        rm -rf "$APP_DIR"
    fi

    # --- 6. Create dir & copy files ---
    mkdir -p "$APP_DIR" || {
        zenity --error --text="Failed to create $APP_DIR"
        return 1
    }

    local APP_FILENAME ICON_FILENAME
    APP_FILENAME=$(basename "$APP_PATH")
    ICON_FILENAME=$(basename "$ICON_PATH")

    cp "$APP_PATH" "$APP_DIR/$APP_FILENAME" || {
        zenity --error --text="Failed to copy executable."
        return 1
    }
    cp "$ICON_PATH" "$APP_DIR/$ICON_FILENAME" || {
        zenity --error --text="Failed to copy icon."
        return 1
    }

    chmod +x "$APP_DIR/$APP_FILENAME"

    # --- 7. Write .desktop file ---
    local DESKTOP_FILE="$HOME/.local/share/applications/${SAFE_NAME}.desktop"
    mkdir -p "$HOME/.local/share/applications"

    cat > "$DESKTOP_FILE" <<EOF
[Desktop Entry]
Name=$APP_NAME
Exec="$APP_DIR/$APP_FILENAME" %U
Icon=$APP_DIR/$ICON_FILENAME
Terminal=false
Type=Application
StartupNotify=true
Categories=Utility;
EOF

    chmod +x "$DESKTOP_FILE"

    # --- 8. Refresh desktop database ---
    if command -v update-desktop-database >/dev/null 2>&1; then
        update-desktop-database "$HOME/.local/share/applications" 2>/dev/null
    fi

    # --- 9. Success message ---
    zenity --info \
        --title="Done" \
        --width=380 \
        --text="<b>✓ $APP_NAME installed!</b>\n\nLocation: $APP_DIR\nLauncher: $DESKTOP_FILE\n\nYou can now launch it from your app menu."

    echo "✓ Installed $APP_NAME at $APP_DIR"
}
