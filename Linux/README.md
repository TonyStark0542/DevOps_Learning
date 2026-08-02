# Server Diagnose Script
A Linux health-check script and troubleshooting methodology for diagnosing slow or overloaded servers.

## Why this exists?
This repo is about diagnosing properly before touching anything. 

## What it does?
- CPU Diagnose
- Memory Diagnose
- Disk Space and Disk I/O Diagnose
- Network Diagnose

## How to Run it?
Clone this repo or else copy the "healthcheck.sh" script file and then do "chmod +x or chmod 700" and then run "./healthcheck.sh"

## Troubleshooting Methodology:
- The Big Picture: what is happing using "uptime" command to see if the load averages exceed my total CPU core count,and run "dmesg --level=err,warn | tail -20" to catch underlying hardware or kernel errors
- CPU: I would run "top" command where i can understand what is happing in CPU and Memory area by this we can understand which process is doing what. And i would also check for saturation by using "vmstat 2 10" in that i would check the r column which is run queue which should not be greater than CPU cores.
- Memory: i will run "vmstat 2 5" this will display the snapshot of memory and swapping by checking si and so column; on-zero values mean the system is starved for RAM and actively thrashing the hard drive and then check the "free -h" command to see the Available memory. To go deeper i would use "ps aux --sort=-%mem" command to find which process is taking more.
- Disk Speed and I/O: I would run "iostat -xz 2 10" and log the %util column for utilization and the aqu-sz column for queue length. also check the "df -h" to find the disk space.
- Network: To check the error and the dropped packages i would run "ip -s link show" for both receive(rx) and transmited(tx) row for my wifi interface. to check the open port list i would use "ss -tuln" and to measure the network throughput i would use "sar -n DEV 2 5" to 
