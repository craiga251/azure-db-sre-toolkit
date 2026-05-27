# Azure Database SRE Toolkit

A practical toolkit demonstrating Site Reliability Engineering practices applied to database operations on Azure. Built to showcase modern SRE skills — Infrastructure as Code, observability, automation, and AI-augmented engineering — combined with deep database operational experience.

## Why This Project

After nearly 20 years operating SQL Server estates at enterprise scale, this project explores how the same operational discipline translates to cloud-native database platforms. It demonstrates how traditional database administration evolves into modern SRE practice through automation, observability, and code.

## Architecture

> _Architecture diagram to be added in Phase 1_

## Tech Stack

- **Cloud:** Microsoft Azure (free tier)
- **Infrastructure as Code:** Terraform
- **CI/CD:** GitHub Actions
- **Compute:** Azure Functions (serverless)
- **Database:** Azure SQL Database (serverless)
- **Observability:** Azure Monitor, Log Analytics, Grafana Cloud
- **Scripting:** PowerShell, Python
- **AI tooling:** GitHub Copilot, LLM APIs for log analysis

## Project Status

| Phase | Status | Description |
|-------|--------|-------------|
| 0 | 🟡 In progress | Foundations and tooling setup |
| 1 | ⬜ Not started | Terraform infrastructure provisioning |
| 2 | ⬜ Not started | Git workflow and CI/CD |
| 3 | ⬜ Not started | SRE automation scripts |
| 4 | ⬜ Not started | Observability and SLIs |
| 5 | ⬜ Not started | AI-augmented operations |
| 6 | ⬜ Not started | Documentation and publishing |

## Repository Structure

```
azure-db-sre-toolkit/
├── terraform/              # Infrastructure as Code
├── scripts/
│   ├── powershell/         # PowerShell automation scripts
│   └── python/             # Python automation scripts
├── .github/
│   └── workflows/          # GitHub Actions CI/CD pipelines
├── docs/                   # Architecture diagrams and design notes
├── README.md
└── .gitignore
```

## Prerequisites

- Azure account (free tier sufficient)
- Azure CLI installed and authenticated
- Terraform CLI (>= 1.5)
- Git and GitHub account
- VS Code with Azure, Terraform, and PowerShell extensions
- Python 3.10+
- PowerShell 7+

## Getting Started

_Setup instructions will be added as the project progresses through Phase 1._

## Design Decisions

_Key architecture and tooling decisions will be documented here as they're made._

## What I Learned

_Lessons, gotchas, and reflections will be captured here throughout the project._

## License

MIT
