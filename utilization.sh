#/bin/bash
proc="firefox-esr"
if (($# < 1)); then 
    echo "Default Process : firefox-esr"
else
    proc=$1
    echo "Process : $1"
fi

echo "CPU, Memory" # > utilization.csv
while [ 1 ]; do
ps -C $proc -o %cpu,%mem | grep -P '\d{1,3}\.\d{1,2}\s{1,3}\d{1,3}\.\d{1,2}' | awk '{ print $1 ",\t" $2}' # >> utilization.csv
done
