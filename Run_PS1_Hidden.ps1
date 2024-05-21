$Win32ShowWindowAsync = Add-Type –memberDefinition @” 
[DllImport("user32.dll")] 
public static extern bool ShowWindowAsync(IntPtr hWnd, int nCmdShow); 
“@ -name “Win32ShowWindowAsync” -namespace Win32Functions –passThru

cd "C:\Users\User1\AppData\Local\Android\Sdk\emulator"  # Change this with your task

$h = Get-Process | Where-Object { $_.MainWindowTitle -match "Android 13"}  #  Get Process with given window title 

$Win32ShowWindowAsync::ShowWindowAsync($h.MainWindowHandle, 0)  # Hides the window


.\emulator.exe -avd Pixel_8_Pro_API_33 # Change this with your task

