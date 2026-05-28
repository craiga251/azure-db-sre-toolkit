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

Several judgement calls during Day 2 are worth capturing — most weren't bugs to fix but decisions where the first instinct (or Copilot's suggestion) wasn't the right one.

**Resource group naming convention.** First attempt named the group `azure-db-sre-toolkit-rg` (suffix-style). Changed to `rg-azure-db-sre-toolkit` (prefix-style) to align with Microsoft's Cloud Adoption Framework guidance. Prefix-first sorts cleanly when resources are filtered by type at scale — small detail, but the convention used in real Azure shops rather than what tutorials default to.

**The `owner` variable.** First version had a hardcoded default of my name. Refactored to remove the default, forcing the value to be supplied via `terraform.tfvars` (gitignored) or `TF_VAR_owner` environment variable. Keeps personal identifying data out of the public repo and matches the pattern used for any environment-specific value in real Terraform projects. Useful general principle: anything that varies between users or environments belongs in variables, not in resource definitions.

**Destroy-recreate cycle felt counterintuitive at first.** Twenty years of treating infrastructure as precious creates a quiet resistance to deleting it deliberately. Running `terraform destroy` and then `terraform apply` to bring the same resource group back from code in under a minute was the moment infrastructure-as-code clicked emotionally rather than just intellectually. The mental shift: infrastructure described in code is disposable; the code is what's precious.

**`(known after apply)` in plan output.** Initially confusing — Terraform showed the resource group's `id` and the `resource_group_id` output as `(known after apply)`. The reason is that Azure assigns the resource ID on creation, so Terraform genuinely doesn't know the value until after the API call. This pattern shows up frequently and is worth recognising rather than treating as something missing.


# Day 3 — Remote State Backend in Azure Storage

## Why this matters

Local state has three disqualifying problems for any real use:
- It is single-machine — losing the laptop loses the ability to manage infrastructure
- It contains secrets in plain text on the local filesystem
- It cannot be safely shared across engineers; concurrent applies corrupt state

Remote state in Azure Storage solves all three: durability via cloud storage, security via access control and encryption, and locking via blob leases to serialise concurrent operations.

## What was built

Bootstrap infrastructure created out-of-band via Azure CLI (since Terraform cannot manage its own backend):
- Separate resource group `rg-terraform-state` isolating bootstrap from project infrastructure
- Storage account `sttfstatesretoolkit` with TLS 1.2 minimum, public blob access disabled, encryption at rest, blob versioning enabled, 7-day soft delete on blobs and containers
- Private container `tfstate` accessed via Azure AD identity rather than account keys

Terraform configuration updated with `backend "azurerm"` block pointing at this infrastructure. State migrated using `terraform init -migrate-state`. Local state files deleted after successful migration.

## Design decisions

- **Bootstrap done manually, not via Terraform.** Chicken-and-egg problem: Terraform needs the backend to exist before it can write state to it. Standard pattern in the industry; documented here so anyone reproducing this knows where the bootstrap commands live.
- **Storage Blob Data Contributor assigned at the storage account scope, not broader.** Least privilege — the role exists only on this single storage account, not the resource group or subscription.
- **Versioning and soft delete enabled.** State files get overwritten on every apply. Versioning gives point-in-time recovery if state ever becomes corrupted. Soft delete protects against accidental container or blob deletion.
- **`allow-blob-public-access` set to false.** State files contain secrets and must never be publicly readable. Explicit at the account level rather than relying on container-level defaults.

## How it would be hardened further in production

- Restrict network access via storage account firewall (specific IPs, VNet integration, or Private Endpoints)
- Disable shared key access entirely (`allowSharedKeyAccess: false`), forcing all authentication via Azure AD
- Use customer-managed keys (CMK) for encryption at rest rather than Microsoft-managed keys
- Apply Azure Policy to prevent regressions on any of the above

## Day 3 reflection

Three issues had to be resolved during the migration that are worth capturing:

**Backend block rejected variable references.** First attempt at the backend configuration considered using variables for the storage account and resource group names. Terraform rejects this — backend blocks must contain hardcoded literal values because the backend has to be resolvable before the rest of the configuration is parsed. Worth remembering: any tutorial showing `${var.something}` inside a backend block is wrong. Hardcode the bootstrap names directly.

**`terraform state list` failed immediately after adding the backend block.** Terraform refused to operate because it had detected a backend change but the new backend hadn't been initialised yet. The error itself was actually helpful — it explicitly suggested `-migrate-state` or `-reconfigure`. Good design choice by Terraform: refuse to guess about state location rather than risk operating on the wrong source of truth.

**`az storage blob list` failed with a permission error despite owning the subscription.** This was the most instructive issue. Creating the storage account and container used *management plane* permissions, which I had via my subscription-level role. Listing blobs *inside* the container is a *data plane* operation requiring an explicit data-plane role assignment — even for the same identity that created the storage account. Resolved by assigning `Storage Blob Data Contributor` scoped specifically to the single storage account (not broader). Key takeaway: Azure's permission model is not flat. "Owner of the subscription" does not imply "can read every blob in every storage account." Data plane access must be granted explicitly, and least-privilege scoping matters even in personal projects because it builds the right habit.

**Side note on PowerShell vs Bash syntax.** PowerShell's `Remove-Item` (aliased as `del`) doesn't accept multiple positional arguments the way CMD or Bash do. Comma-separated form (`del file1, file2`) or separate commands are needed. Small thing but worth knowing — Bash and PowerShell have similar-looking commands with subtly different behaviours.