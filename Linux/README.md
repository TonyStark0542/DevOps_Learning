# Server Diagnose Script
 
A Linux health-check script and troubleshooting methodology for diagnosing slow or overloaded servers.
 
## Why this exists
 
When a Linux server is slow, the instinct is to jump straight to one command and guess — but the real bottleneck could be CPU, memory, disk, or network, and checking each one by hand takes time and is easy to get wrong under pressure. This script runs all the key checks in one shot, so you can see where the actual problem is before touching anything.
 
I'm rebuilding my Linux troubleshooting knowledge from the ground up, and this repo is part of that. I'd been running these commands for a while without a real order to them, and without fully understanding what some of the numbers meant. Writing this script forced me to justify every check I was including — why this command, what column matters, and what the value actually tells me.
 
The biggest thing I'd been getting wrong: I assumed a high load average meant something was eating the CPU. It doesn't necessarily. That's covered in the CPU section below.
 
## What it does
 
- CPU diagnosis
- Memory diagnosis
- Disk space and disk I/O diagnosis
- Network diagnosis
## How to run it
 
Clone this repo, or just copy the `healthcheck.sh` script file on its own. Then make it executable and run it:
 
```bash
chmod +x healthcheck.sh
./healthcheck.sh
```
 
(`chmod 700` also works if you want to restrict it to just yourself.)
 
## Troubleshooting methodology
 
This is the actual thought process I follow when a server is acting up — the script automates these checks, but this is the reasoning behind why each one matters.
 
### 1. The big picture
 
Before diving into any one resource, I start with `uptime` to see the load averages and compare them against the number of CPU cores on the box. If the load average is consistently higher than the core count, the system is genuinely overloaded, not just busy.
 
I also run:
 
```bash
dmesg --level=err,warn | tail -20
```
 
This catches any underlying hardware or kernel-level errors that might be the actual root cause — sometimes what looks like a performance issue is really a failing disk or a driver problem showing up in the kernel log.

### 2. CPU
 
To check for CPU saturation, I run:
 
```bash
vmstat 2 10
```
 
Two things matter in this output.
 
**The `r` column** shows the run queue — how many processes are waiting for CPU time. If this is consistently higher than the number of CPU cores, processes are genuinely queuing up and the CPU is saturated.
 
**The `wa` column** shows iowait, and this is the one I'd been ignoring. Load average counts processes that are *waiting*, not just processes that are running — and that includes processes blocked on disk I/O. So a server can show a high load average while the CPU sits mostly idle, because everything is stuck behind slow disk.
 
The way to tell them apart:
 
- High `r`, high `us`/`sy`, low `wa` → the CPU really is the bottleneck
- Low `r`, low `us`/`sy`, high `wa` → the CPU is idle and waiting on disk. Adding CPU won't help. Go check disk I/O instead.
I also check which processes are consuming the most CPU:
 
```bash
ps aux --sort=-%cpu | head -10
```
 
(`top` shows the same thing interactively, but `ps` works inside a script that runs and exits.)

<img width="1766" height="972" alt="Screenshot From 2026-08-03 00-51-58" src="https://github.com/user-attachments/assets/7e41901d-deea-442f-80ce-9f99e09c6e0d" />

 
### 3. Memory
 
I start with:
 
```bash
vmstat 2 5
```
 
This gives a snapshot of memory and swap activity. I'm specifically watching the `si` and `so` columns (swap in / swap out). Any non-zero values here mean the system is starved for RAM and is actively swapping to disk — which is much slower than RAM and usually the real reason things feel sluggish.
 
Then I check overall available memory with:
 
```bash
free -h
```
 
If I need to go deeper and find exactly which process is eating memory, I run:
 
```bash
ps aux --sort=-%mem
```
 
This sorts every running process by memory usage, so the heaviest consumer shows up right at the top.

<img width="1766" height="926" alt="Screenshot From 2026-08-03 00-52-45" src="https://github.com/user-attachments/assets/66d81512-1411-4f44-8193-49ec594527d2" />

 
### 4. Disk speed and I/O
 
For disk performance, I run:
 
```bash
iostat -xz 2 5
```
 
Two columns matter most here: `%util`, which tells me how busy the disk actually is, and `aqu-sz`, which shows the average queue length — how many I/O requests are waiting to be processed. High values on either point to the disk being a bottleneck, not the CPU or memory.
 
I also check plain disk space with:
 
```bash
df -h
```
 
since a server that's simply out of space can look like a performance issue at first glance.

<img width="1915" height="380" alt="Screenshot From 2026-08-03 00-54-09" src="https://github.com/user-attachments/assets/d5bda9ea-040e-4647-bf47-81e74499e555" />
<img width="1915" height="963" alt="Screenshot From 2026-08-03 00-53-40" src="https://github.com/user-attachments/assets/34101423-8a56-4111-886f-99f42f79c652" />
<img width="1766" height="443" alt="Screenshot From 2026-08-03 00-53-22" src="https://github.com/user-attachments/assets/755d5e35-5300-4afb-896a-f89ce5d28991" />

 
### 5. Network
 
To check for errors or dropped packets, I run:
 
```bash
ip -s link show
```
 
and look at both the receive (rx) and transmit (tx) rows for the relevant network interface. Dropped or errored packets here point to a network-level problem rather than something happening inside the server itself.
 
To see which ports are open and listening, I use:
 
```bash
ss -tuln
```
 
And to actually measure network throughput over a short window, I run:
 
```bash
sar -n DEV 2 5
```
 
This shows real send/receive rates on the interface, which tells me if the server is actually pushing a lot of traffic or if the network is idle while something else is the real problem.

<img width="1915" height="817" alt="Screenshot From 2026-08-03 00-54-33" src="https://github.com/user-attachments/assets/58a5dab9-bccb-491b-b79b-950a4583717c" />
<img width="1915" height="952" alt="Screenshot From 2026-08-03 00-55-12" src="https://github.com/user-attachments/assets/2a7194da-6348-40b4-a6b1-08cfac9c8fcc" />
<img width="1915" height="952" alt="Screenshot From 2026-08-03 00-55-25" src="https://github.com/user-attachments/assets/ac48a125-795d-4802-a5ac-97305e22fba0" />
