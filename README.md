# DevOps_Learning

This is where I'm documenting my move from production support into DevOps and cloud engineering — the projects I build, the scripts I write, and the things I get wrong along the way.

I'm doing this in public because writing something down forces me to actually understand it. It's easy to run a command and feel like you know it. It's much harder to explain why you ran it, what the output means, and what you'd do next. This repo is me making myself do the harder version.

## Background

I work in production support, mostly around enterprise ETL pipelines on Ab Initio, across Unix and Linux servers. That gave me a decent feel for how things break in production — incidents, on-call, root-cause work — but no exposure to the tooling side of DevOps.

So I've been building that side myself. Google Cloud Associate Cloud Engineer certified, and everything below is hands-on work rather than course exercises.

## Projects

Each of these lives in its own repo with its own README explaining what it does and why it's built that way.

| Project | What it covers |
|---|---|
| [Three-Tier-GKE-App](https://github.com/TonyStark0542/Three-Tier-GKE-App) | Three-tier bookstore app on Google Kubernetes Engine — Deployments, Services, PersistentVolumeClaim, Ingress-based routing, and a Prometheus/Grafana monitoring stack via Helm |
| [Bookstore-Microservices](https://github.com/TonyStark0542/Bookstore-Microservices) | The same app rebuilt as microservices, deployed through a Jenkins CI/CD pipeline. Terraform provisions the Jenkins server itself. Includes a Gemini-powered book summary endpoint and a pre-flight validation script |
| [gcp_iac_project](https://github.com/TonyStark0542/gcp_iac_project) | Terraform provisions two VMs (Ubuntu and CentOS), Ansible configures both identically despite different package managers. Includes a reusable Nginx role and a lab bootstrap script |

## Scripts in this repo

Smaller standalone things that don't warrant their own repo.

- **[`Linux/`](Linux/)** — A Linux health-check script and the troubleshooting methodology behind it. Runs CPU, memory, disk, and network checks in one pass and flags which columns actually matter in each output. The README in that folder explains the reasoning for every check, not just the commands.

## Learning in public

I post about what I'm working through on LinkedIn as I go — usually whatever I got wrong that week and what fixed my understanding of it. This repo is what those posts point back to.

The format I'm trying to stick to: pick one thing, understand it properly rather than just enough to use it, write down the reasoning, then move on. Depth over coverage.

## Currently working on

- Rebuilding Linux troubleshooting from the ground up, one subsystem at a time
- Getting more comfortable with GitHub Actions (I've used Jenkins more so far)
- Networking fundamentals on GCP — VPCs, subnets, load balancing

## Things I'm still weak on

Keeping this section honest is part of the point.

- Ansible beyond the basics — I can write playbooks and roles, but haven't touched dynamic inventory or more complex patterns
- Security tooling — I handle secrets properly in the projects above, but haven't worked with dedicated scanning or policy tools
- Production-scale Kubernetes — my clusters are small and low-traffic, so I haven't dealt with real scaling or failure scenarios

---

Feedback and corrections are genuinely welcome. If something in here is wrong or there's a better way to do it, open an issue — I'd rather find out from someone who knows than keep repeating it.
