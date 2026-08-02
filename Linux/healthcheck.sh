#!/bin/bash

# Identity
echo "Hostname: $(hostname)"
echo "Date & Time: $(date)"
echo "Uptime: $(uptime)"
echo "Kernal Version: $(uname -r)"
echo "OS: $(grep "PRETTY_NAME" /etc/os-release | cut -d'"' -f2)"
echo ""

# first we will be find the saturation of CPU:
echo "CPU Details:"
echo "CPU Cores: $(nproc)" && top -b -n 1 | awk '/load average:/ {print "Load Average:" $NF-2, $NF-1, $NF} /%Cpu\(s\):/ {for(i=1;i<=NF;i++) if($i~/wa/) print "IO Wait: " $(i-1) "%"}'
echo ""
echo "Check for CPU & Memory Saturation:"
vmstat 2 10
echo ""

# Memory & Swap Details
echo "Check for Memory & Swap Details:"
free -h
echo ""
ps aux --sort=-%mem | head -20 | awk '
NR==1 {
    printf "%-10s %-7s %-5s %-5s %8s %9s %s\n", "USER", "PID", "%CPU", "%MEM", "VSZ(GB)", "RSS(MB)", "COMMAND"
}
NR>1 {
    split($11, a, "/")
    printf "%-10s %-7s %-5s %-5s %6.2fGB %7.1fMB %s\n", $1, $2, $3, $4, $5/1024/1024, $6/1024, a[length(a)]
}'| column -t

# Disk space and Disk i/o & inodes:
echo ""
echo "Check Disk Space:"
df -h
echo ""
echo "Check Disk I/O:"
iostat -xz 2 5

# Network:
echo ""
echo "Check the network interface physical error:"
ip -s link show
echo "Network Open Ports:"
ss -tuln
echo ""
echo "Network Utilization:"
sar -n DEV 2 5
