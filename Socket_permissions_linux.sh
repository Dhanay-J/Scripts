# Set Socket Permisiions for executable 'main'
sudo chown root:root main
sudo chmod u+s  main

# Or 
sudo setcap CAP_NET_RAW+eip main

# For python files
sudo -E python myScriptName.py
