$ip=Get-NetIPAddress | Where-Object { $_.IPAddress -match '^192\.168\.1\.' } | Select-Object IPAddress
ping $ip.IPAddress
