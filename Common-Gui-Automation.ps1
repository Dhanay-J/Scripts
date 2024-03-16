# Import Windows Forms assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing


# Create a form object
$form = New-Object System.Windows.Forms.Form
$form.Size = New-Object System.Drawing.Size(600,600) 

# Add Drop Box
$dropBox = New-Object System.Windows.Forms.ComboBox
$dropBox.Location = New-Object System.Drawing.Size(10,10)
$dropBox.Size = New-Object System.Drawing.Size(200)


# Get all network adapters
$adapters = Get-NetAdapter -IncludeHidden

# Initialize an empty array to store IPs
$ipAddresses = @()

# Loop through each adapter
foreach ($adapter in $adapters) {
  
  # Check if the adapter is enabled (skip disabled ones)
  if ($adapter.Status -eq "Up" ) {
    
    # Get IP address information for the enabled adapter
    if ($adapter -eq $null){
        continue
    }
    
    $ipInfo = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex
    
    # Extract IP address from the information
    $ipAddress = $ipInfo.IPAddress[1]
    
    # Add the extracted IP to the array
    $ipAddresses += $ipAddress


  }
}

#Clear Screen
cls

$ipAddresses = $ipAddresses | Select-Object -Unique

# If no IPs found, inform the user
if ($ipAddresses.Count -eq 0) {
  Write-Host "No available IP addresses found. Exiting"
  exit -1
} else {
    
    


    # Set ip to dropbox items
    foreach($ip in $ipAddresses){
    
        $dropBox.Items.Add($ip)
    }
    
    #Set a default value in drop down
    $dropBox.SelectedIndex = 0
    


    # Create a text box
    $textBox = New-Object System.Windows.Forms.RichTextBox
    $textBox.Location = New-Object System.Drawing.Size(10,100)
    $textBox.Size = New-Object System.Drawing.Size(300, 300)
    $textBox.Font = New-Object System.Drawing.Font("Sans", 24.0)
    $textBox.Multiline = $true
    $textBox.ReadOnly = $true
    $textBox.ScrollBars = "Vertical"
    $textBox.Text = "Getting IP"


    # Add controls to Form
    $form.Controls.Add($dropBox)    
    $form.Controls.Add($textBox)

    # Display the form and capture selection (more code needed here)
    $form.ShowDialog()
}

