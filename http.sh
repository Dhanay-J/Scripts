alias http='echo "IP Address : " && ifconfig  | grep "inet .* n" -o | grep  -P "\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}" -o && sudo python3 -m http.server -b 0.0.0.0 80'

