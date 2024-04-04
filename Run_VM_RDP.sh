# Get the ID and security principal of the current user account
$myWindowsID = [System.Security.Principal.WindowsIdentity]::GetCurrent();
$myWindowsPrincipal = New-Object System.Security.Principal.WindowsPrincipal($myWindowsID);

# Get the security principal for the administrator role
$adminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator;

# Check to see if we are currently running as an administrator
if ($myWindowsPrincipal.IsInRole($adminRole))
{
    # We are running as an administrator, so change the title and background colour to indicate this
    $Host.UI.RawUI.WindowTitle = $myInvocation.MyCommand.Definition + "(Elevated)";
    $Host.UI.RawUI.BackgroundColor = "DarkBlue";
    Clear-Host;
}
else {
    # We are not running as an administrator, so relaunch as administrator

    # Create a new process object that starts PowerShell
    $newProcess = New-Object System.Diagnostics.ProcessStartInfo "PowerShell";
    $newProcess.CreateNoWindow = $true
    $newProcess.WindowStyle = "Hidden"



    # Specify the current script path and name as a parameter with added scope and support for scripts with spaces in it's path
    $newProcess.Arguments = "& '" + $script:MyInvocation.MyCommand.Path + "'"

    # Indicate that the process should be elevated
    $newProcess.Verb = "runas";

    # Start the new process
    [System.Diagnostics.Process]::Start($newProcess);

    # Exit from the current, unelevated, process
    Exit;
}


# Run your code that needs to be elevated here...

Start-VM -Name MyVm # Start Vn with Name 'MyVm' 

while ($True) {
  # Get process list and filter for lines containing 'vm' (case-insensitive)
  $vmCount = (Get-Process | Where-Object { $_.Name -match "vm"  }) | Measure-Object | Select-Object -ExpandProperty Count

  # Exit the loop if vmCount is less than 6
  if ($vmCount -ge 6) {
    break
  }

  # Wait for a short duration before checking again (adjust as needed)
  Start-Sleep -Seconds 2

  #Write-Host "Waiting... vmCount: $vmCount"
}

# Connect with RDP
mstsc.exe /v 192.168.1.48 # ip of Gust os
