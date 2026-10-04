#!/bin/bash
# samples IOAccelerator Device Utilization % once a second to $1
while true; do
  u=$(ioreg -r -d 1 -c IOAccelerator 2>/dev/null | grep -oE '"Device Utilization %"=[0-9]+' | head -1 | grep -oE '[0-9]+$')
  echo "$(date +%H:%M:%S) gpu_util $u load $(sysctl -n vm.loadavg | awk '{print $2}')" >> "$1"
  sleep 1
done
