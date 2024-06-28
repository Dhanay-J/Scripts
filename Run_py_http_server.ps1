echo "Valid IP addresses are:"
(ipconfig.exe | findstr.exe 'IPv4' |Select-String -Pattern '\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b' -AllMatches).Matches.Value
echo ""
py -m http.server -b 0.0.0.0 80
