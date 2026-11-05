# Waydroid WhatsApp Setup

## 1. Initial check
```bash
sudo waydroid shell
am start -a android.intent.action.VIEW -d "whatsapp://send/?phone=917304459222&text=hi"
```
Ensure WhatsApp opens correctly.

## 2. User sudo setup
```bash
sudo groupadd waydroid
sudo usermod -aG waydroid $USER
```
Reboot. Then `sudo visudo` and add at end:
```sudoers
%waydroid ALL=(ALL) NOPASSWD: /usr/bin/waydroid shell *
```
The `*` is required, else args won't match.

Test:
```bash
sudo -k
sudo waydroid shell -- sh -c 'echo test'
```
No password prompt = good.

## 3. Create script
* Change the user name (here it is `ubuntu`) as per the system. \
`/home/ubuntu/.local/share/applications/open-whatsapp.sh`:
```bash
#!/bin/bash
APP_PACKAGE="com.whatsapp"
URL="$1"
if [ -z "$URL" ]; then
    waydroid app launch "$APP_PACKAGE"
else
    sudo waydroid shell -- sh -c "am start -a android.intent.action.VIEW -d \"$URL\""
fi
exit $?
```
```bash
chmod +x /home/ubuntu/.local/share/applications/open-whatsapp.sh
```
Test both cases without password prompt.

## 4. Edit desktop file
`~/.local/share/applications/waydroid.com.whatsapp.desktop`
```desktop
Exec=/home/ubuntu/.local/share/applications/open-whatsapp.sh %u
MimeType=x-scheme-handler/whatsapp;
```
Adjust path if script is elsewhere. Then:
```bash
chmod +x ~/.local/share/applications/waydroid.com.whatsapp.desktop
update-desktop-database ~/.local/share/applications/
```

## 5. Add MIME handler
```bash
xdg-mime default waydroid.com.whatsapp.desktop x-scheme-handler/whatsapp
```

Verify:
```bash
gio open "whatsapp://send/?phone=917304459222&text=hi"
```

