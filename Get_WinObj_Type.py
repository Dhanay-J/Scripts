type_of_object = str(subprocess.check_output(['powershell.exe ','Add-Type -AssemblyName System.Windows.Forms;','$btn = New-Object System.Windows.Forms.Button;',' Write-Host $btn.GetType().BaseType.BaseType'], shell=True).decode()).strip()
print(type_of_object)
