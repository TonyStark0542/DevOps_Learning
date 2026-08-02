# Server Diagnose Script

A Linux health-check script and troubleshooting methodology for diagnosing slow or overloaded servers.

## Why this exists

When a Linux server is slow, the instinct is to jump straight to one command and guess — but the real bottleneck could be CPU, memory, disk, or network, and checking each one by hand takes time and is easy to get wrong under pressure. This script runs all the key checks in one shot, so you can see where the actual problem is before touching anything.

I built this after realizing I kept running the same handful of commands every time a server felt slow, in a different order each time, and sometimes missing one entirely. This script just automates that first pass so the information is all in front of me immediately.

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

I run `top` first to see what's actually happening on the CPU and memory side — which processes are consuming what, and whether one process is clearly the culprit or the load is spread out.

To check for CPU saturation specifically, I run:

```bash
vmstat 2 10
```

Here I'm watching the `r` column, which shows the run queue — the number of processes waiting for CPU time. If this number is consistently higher than the number of CPU cores, processes are queued up waiting their turn, which is a clear sign of CPU saturation.

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
