# Day 1 — Core Concepts

Working notes capturing the four fundamentals of Terraform. Phrased to be interview-ready, not just memorised.

## Providers

A provider is a plugin that lets Terraform interact with a specific platform's API — for Azure, this is the `azurerm` provider, which translates Terraform's declarative configuration into calls against Azure's Resource Manager API. Each provider abstracts a platform's resources into Terraform's model, so you describe what you want and the provider handles the underlying API calls. Providers are versioned and pinned in configuration to ensure deployments remain reproducible as upstream APIs evolve. Without a provider, Terraform has no knowledge of how to create or manage anything on a given platform.

## State

State is the file where Terraform records the IDs, properties, and metadata of every resource it manages. It serves as the source of truth that Terraform compares against your configuration to decide what to create, change, or destroy.

State is dangerous for two main reasons:

- **It contains sensitive values in plain text.** Database admin passwords, connection strings, and secrets are all stored unencrypted. The state file must therefore be treated as a secret itself — stored in a private, access-controlled location, never committed to source control.
- **It is the only non-reproducible part of a Terraform project.** Code can be rebuilt from Git, providers from `terraform init`, but if state is lost Terraform no longer knows which real resources it manages. Recovery means either importing every resource manually or destroying and recreating everything.

State also drifts when infrastructure is changed outside Terraform (manual portal edits, scripts, other tools). Terraform will then either try to "correct" reality destructively or fail confusingly — which is why remote state with locking and a no-manual-changes discipline matter in production.

## Plan vs Apply

`terraform plan` is a dry-run that shows exactly what Terraform will create, change, or destroy if applied — without doing any of it. `terraform apply` executes those changes.

The separation matters because plan is the safety mechanism that makes Terraform suitable for SRE work rather than just convenient scripting:

- You can review the blast radius of a change before it happens.
- Plans can be gated in CI/CD, so other engineers review infrastructure changes the same way they review application code.
- Mistakes that would otherwise hit production get caught at PR stage.
- The plan output becomes a record of what was intended, separate from what actually ran.

The strong answer to "why use Terraform over a script that calls the Azure CLI?" lives here — it's the discipline of always seeing the change before making it.

## `.terraform` folder vs state file

These are two very different things, and confusing them causes real outages.

- **`.terraform/` (local folder)** — Contains downloaded providers, modules, and cached plugin binaries. It is fully reproducible from your configuration by running `terraform init`. Safe to delete; safe to `.gitignore`. Losing it costs only the time to re-download.

- **State file** — Contains the actual record of what Terraform manages. Not reproducible from code. Losing it means Terraform no longer has any link between your configuration and the real resources that exist in Azure. This is why remote state in Azure Storage matters: it's backed up, versioned, and access-controlled, rather than sitting on a single laptop.

The mental model: `.terraform/` is the toolbox (replaceable); state is the inventory record (irreplaceable).

# Day 2 — First Terraform Configuration

## What was built

A minimal Terraform configuration creating a single Azure resource group in UK South with project, ownership, and management tags. Files: `main.tf`, `variables.tf`, `outputs.tf`. State remains local for now; remote backend follows on Day 3.

## Terraform vs ARM Deployment History

When resources are created via the Azure portal, ARM templates, or Bicep, each change is recorded as a "deployment" in the resource group's deployment history blade. This provides a unified audit trail visible directly in the portal.

Terraform behaves differently. It calls Azure's resource APIs directly rather than going through the ARM deployment engine, so no entries appear in the deployment history. The audit trail instead lives in two places: the Terraform state file (what currently exists and its properties) and the git history of the configuration (who changed what, when, and why).

This is a deliberate architectural tradeoff worth being able to discuss:

- **Argument for Terraform's approach:** there is a single source of truth. Reviewing a PR shows you the intended change; the state file shows you the resulting infrastructure. Nothing is hidden in a portal blade that requires separate access to inspect.
- **Argument against:** teams used to the portal-based audit view lose that unified history, and engineers without Terraform access (e.g. compliance auditors) need a different path to see what changed.

In practice, mature teams accept the tradeoff because the git-based audit trail is richer — commit messages and PR descriptions capture the reasoning behind changes, not just the mechanical change itself.

## Design decisions

- **`owner` variable has no default.** Forces the value to be supplied via `terraform.tfvars` (gitignored) or `TF_VAR_owner`. Keeps personal identifying data out of the public repository.
- **Resource group named with `rg-` prefix.** Matches Microsoft's Cloud Adoption Framework naming convention; resources sort cleanly when filtered by type at scale.
- **Region set to `uksouth`.** Matches target market (UK financial services) for latency and data residency. Default `eastus` from generic tutorials rejected as inappropriate.
- **All resources tagged at creation.** `project`, `managed_by`, `owner` applied via Terraform rather than retrofitted later. Mandatory tagging is standard practice in any production Azure environment for cost allocation and ownership tracking.

## Day 2 reflection

In the main Day 2 went well, I had some issues running commands due to executables not in my PATH which needed updated.  Also will use consistency in types when going Github commits going forward.
