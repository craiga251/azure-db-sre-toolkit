# Azure Database SRE Toolkit

A practical toolkit demonstrating Site Reliability Engineering practices applied to database operations on Azure. Built to showcase modern SRE skills — Infrastructure as Code, observability, automation, and AI-augmented engineering — combined with deep database operational experience.

## Why This Project

After nearly 20 years operating SQL Server estates at enterprise scale, this project explores how the same operational discipline translates to cloud-native database platforms. It demonstrates how traditional database administration evolves into modern SRE practice through automation, observability, and code.

## Architecture

> _Architecture diagram to be added during Phase 1._

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
| 0 | ✅ Complete | Foundations and tooling setup |
| 1 | 🟡 In progress | Terraform infrastructure provisioning |
| 2 | ⬜ Not started | Git workflow and CI/CD |
| 3 | ⬜ Not started | SRE automation scripts |
| 4 | ⬜ Not started | Observability and SLIs |
| 5 | ⬜ Not started | AI-augmented operations |
| 6 | ⬜ Not started | Documentation and publishing |

## Repository Structure

```
azure-db-sre-toolkit/
├── terraform/              # Infrastructure as Code (Phase 1)
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── .terraform.lock.hcl
├── scripts/
│   ├── powershell/         # PowerShell automation scripts (Phase 3)
│   └── python/             # Python automation scripts (Phase 3)
├── .github/
│   └── workflows/          # GitHub Actions CI/CD pipelines (Phase 2)
├── docs/
│   └── terraform-notes.md  # Design decisions and reflections
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

> _Full setup instructions will be expanded once Phase 1 (infrastructure provisioning) is complete._

**Current state:** Phase 1 in progress. Terraform configuration provisions a single resource group with remote state backed by Azure Storage. Azure SQL Database, Functions, and observability resources will be added during the remainder of Phase 1.

To reproduce the current state:

1. Clone this repository
2. Authenticate to Azure: `az login`
3. Bootstrap the remote state backend — see the bootstrap commands documented in [`docs/terraform-notes.md`](docs/terraform-notes.md)
4. In the `terraform/` folder, copy `terraform.tfvars.example` to `terraform.tfvars` and set the `owner` variable
5. Run `terraform init`, `terraform plan`, then `terraform apply`

## Design Decisions

Key architectural and tooling decisions are documented as they are made in [`docs/terraform-notes.md`](docs/terraform-notes.md). Highlights include the remote state backend design, naming conventions following Microsoft's Cloud Adoption Framework guidance, and the rationale for bootstrap infrastructure being created out-of-band rather than via Terraform.

## What I Learned

Reflections and lessons captured per phase in [`docs/terraform-notes.md`](docs/terraform-notes.md). Includes notes on Copilot's contextual blind spots, Azure's data plane vs management plane permission model, and the conceptual shift from infrastructure-as-precious to infrastructure-as-code.

## License

MIT
