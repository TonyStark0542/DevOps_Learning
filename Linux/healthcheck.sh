#!/bin/bash

# Simple separator so each section is easy to spot when scrolling through output
line() {
    echo "-----------------------------------------------------"
}

# Check a command exists before relying on it, so the script fails
# with a clear message instead of a random "command not found" mid-run
require() {
    if ! command -v "$1" &> /dev/null; then
        echo "Note: '$1' is not installed. Skipping that check."
        echo "(On Debian/Ubuntu: sudo apt install sysstat iproute2)"
        return 1
    fi
    return 0
}

line
echo "Hostname: $(hostname)"
echo "Date & Time: $(date)"
echo "Uptime: $(uptime)"
echo "Kernel Version: $(uname -r)"
echo "OS: $(grep "PRETTY_NAME" /etc/os-release | cut -d'"' -f2)"
line

# The big picture — load average vs core count, plus any kernel-level
# errors that might be the real root cause instead of a resource bottleneck
echo "System Overview:"
echo "CPU Cores: $(nproc)"
echo "Load Average:$(uptime | awk -F'load average:' '{print $2}')"
echo ""
echo "Recent kernel errors/warnings:"
dmesg --level=err,warn 2>/dev/null | tail -20 || echo "(dmesg needs sudo to read the kernel ring buffer — try running this script with sudo)"
line

# CPU saturation check
echo "CPU Details:"
echo "Watch 'r' (run queue) vs core count for CPU saturation."
echo "Also watch 'wa' (iowait) — high 'wa' with low 'us'/'sy' means the CPU"
echo "is idle and waiting on disk, not overloaded. Check disk I/O below."
vmstat 2 10
echo ""
ps aux --sort=-%cpu | head -10 | awk '
NR==1 {
    printf "%-10s %-7s %-5s %-5s %9s %s\n", "USER","PID","%CPU","%MEM","RSS(MB)","COMMAND"
}
NR>1 {
    split($11, a, "/")
    printf "%-10s %-7s %-5s %-5s %7.1fMB %s\n", $1,$2,$3,$4, $6/1024, a[length(a)]
}' | column -t
line

# Memory & Swap Details
echo "Memory & Swap Details:"
echo "Watch the 'si' and 'so' columns — non-zero means active swapping:"
vmstat 2 5
echo ""
free -h
echo ""
echo "Top memory-consuming processes:"
ps aux --sort=-%mem | head -20 | awk '
NR==1 {
    printf "%-10s %-7s %-5s %-5s %9s %s\n", "USER","PID","%CPU","%MEM","RSS(MB)","COMMAND"
}
NR>1 {
    split($11, a, "/")
    printf "%-10s %-7s %-5s %-5s %7.1fMB %s\n", $1,$2,$3,$4, $6/1024, a[length(a)]
}' | column -t
line

# Disk space and Disk I/O & inodes:
echo "Check Disk Space:"
df -h
echo ""
echo "Check Disk I/O (watch %util and aqu-sz):"
if require iostat; then
    iostat -xz 2 5
fi
line

# Network:
echo "Check the network interface for physical errors (rx/tx):"
ip -s link show
echo ""
echo "Network Open Ports:"
if require ss; then
    ss -tuln
fi
echo ""
echo "Network Utilization:"
if require sar; then
    sar -n DEV 2 5
fi
line
