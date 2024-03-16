# Import Windows Forms assemblies
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

function createDropBox{
    param($x,$y,$width)
    # Add Combo Box
    $comboBox = New-Object System.Windows.Forms.ComboBox
    $comboBox.Font = New-Object System.Drawing.Font("Sans", 16)
    $comboBox.Location = New-Object System.Drawing.Size($x,$y)
    $comboBox.Size = New-Object System.Drawing.Size($width)

    return $comboBox
}

function getIpArray{
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

    return $ipAddresses

}

function createTextBox{
    param($x, $y, $w,$h , $font_size)
    # Create a text box
    $textBox = New-Object System.Windows.Forms.RichTextBox
    $textBox.Location = New-Object System.Drawing.Size($x,$y)
    $textBox.Size = New-Object System.Drawing.Size($w, $h)
    $textBox.Font = New-Object System.Drawing.Font("Sans", $font_size)
    $textBox.Multiline = $true
    $textBox.ReadOnly = $true
    $textBox.ScrollBars = "Vertical"
    return $textBox
}

function createButton{
    param($x,$y,$w=80,$h=30,$text="Button")
    #Create Button 
    $btn = New-Object System.Windows.Forms.Button
    $btn.Location = New-Object System.Drawing.Size($x,$y)
    $btn.Size = New-Object System.Drawing.Size($w, $h)
    $btn.Text = $text

    return $btn
}

function addControls {
  
  if($args.Count -gt 0){
      
      
      foreach($control in $args){
        # Test object for testing compatibility
        $comparator_obj = New-Object System.Windows.Forms.Button
        $comparator_type = $comparator_obj.GetType() | Select-Object -ExpandProperty BaseType;
        
        $control_type = $control.GetType() | Select-Object -ExpandProperty BaseType;
        
        # Order of comparison is non commutative
        $res = $comparator_type.BaseType -eq $control_type.BaseType
        
        if ($res) {
            
            $form.Controls.Add($control)
        }

      }

  }
  else{
        Write-Host "No Controls Given"
  }
}


# Create a form object
$form = New-Object System.Windows.Forms.Form
$form.Size = New-Object System.Drawing.Size(600,600) 


# Initialize an empty array to store IPs
$ipAddresses = getIpArray

# If no IPs found, inform the user
if ($ipAddresses.Count -eq 0) {
  Write-Host "No available IP addresses found. Exiting"
  exit -1
}
else {
    
    # Add Drop Box with pasition x y and width 
    $dropBox = createDropBox 10 10 200

    # Set ip to dropbox items
    foreach($ip in $ipAddresses){
        $dropBox.Items.Add($ip)
    }
    
    #Set a default value in drop down
    $dropBox.SelectedIndex = 0

    # Create a text box
    $textBox = createTextBox 10 50 400 120 18.0
    $textBox.Text = "Getting IP"


    #Create Button 
    $btn = createButton 10 180 80 30 "Submit"



    # Add controls to Form
    addControls $dropBox $textBox $btn

    

    # Display the form and capture selection (more code needed here)
    $form.ShowDialog()
}
