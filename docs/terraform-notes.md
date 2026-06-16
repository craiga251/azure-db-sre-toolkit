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

## Bootstrap commands (one-time setup)

The following Azure CLI commands create the state backend infrastructure outside of Terraform. Run once per environment.

When reproducing this in a new environment, two values must be customised:

- `<storage-account-name>` — must be globally unique across all of Azure, lowercase letters and numbers only, 3–24 characters.
- `<owner>` — the identifier recorded in the `owner` tag (your name, team, or similar).

The commands below show the names actually used in this project. Substitute your own where appropriate.

### 1. Confirm the correct subscription is active

```powershell
az account show
```

Verify the returned `id` matches the intended subscription before continuing.

### 2. Create the state-backend resource group

```powershell
az group create `
  --name rg-terraform-state `
  --location uksouth `
  --tags managed_by=manual purpose=terraform-state-backend owner=<owner>
```

The `managed_by=manual` tag is deliberate: this resource group is explicitly *not* managed by Terraform, and the tag prevents future confusion about why it isn't in any `.tf` file.

### 3. Create the storage account

```powershell
az storage account create `
  --name sttfstatesretoolkit `
  --resource-group rg-terraform-state `
  --location uksouth `
  --sku Standard_LRS `
  --kind StorageV2 `
  --min-tls-version TLS1_2 `
  --allow-blob-public-access false `
  --tags managed_by=manual purpose=terraform-state-backend owner=<owner>
```

Flag rationale:

- `--sku Standard_LRS` — locally-redundant storage; cheapest tier, sufficient for state in a personal project. Production might use `Standard_GRS` for geo-redundancy.
- `--kind StorageV2` — modern general-purpose v2 account; v1 is legacy.
- `--min-tls-version TLS1_2` — refuses connections using older, weaker TLS versions.
- `--allow-blob-public-access false` — critical for state files; state contains secrets and must never be publicly readable.

### 4. Enable blob versioning and soft delete

```powershell
az storage account blob-service-properties update `
  --account-name sttfstatesretoolkit `
  --resource-group rg-terraform-state `
  --enable-versioning true `
  --enable-delete-retention true `
  --delete-retention-days 7 `
  --enable-container-delete-retention true `
  --container-delete-retention-days 7
```

State files are overwritten on every `terraform apply`. Versioning retains every previous version so corrupted state can be rolled back. Soft delete provides a 7-day recovery window for accidentally deleted blobs and containers.

### 5. Create the blob container

```powershell
az storage container create `
  --name tfstate `
  --account-name sttfstatesretoolkit `
  --auth-mode login
```

`--auth-mode login` uses the current Azure AD identity rather than storage account keys. This is the modern, recommended authentication path.

### 6. Grant data plane access to your user

Creating the container via `--auth-mode login` requires the user to have a data-plane role on the storage account. Subscription-level Owner is *not* sufficient for data plane operations — Azure's permission model separates management plane (creating the account) from data plane (reading and writing blobs inside it).

Retrieve the current user's object ID and assign the role, scoped to the single storage account:

```powershell
$userId = az ad signed-in-user show --query id -o tsv

az role assignment create `
  --role "Storage Blob Data Contributor" `
  --assignee $userId `
  --scope /subscriptions/<subscription-id>/resourceGroups/rg-terraform-state/providers/Microsoft.Storage/storageAccounts/sttfstatesretoolkit
```

Role assignments take 1–2 minutes to propagate. Verify with:

```powershell
az storage blob list `
  --account-name sttfstatesretoolkit `
  --container-name tfstate `
  --auth-mode login `
  --query "[].name"
```

### 7. Update Terraform configuration and migrate state

Once the bootstrap infrastructure exists, add the `backend "azurerm"` block to `main.tf` referencing the resource names above, then migrate any existing local state:

```powershell
terraform init -migrate-state
```

Confirm `yes` when prompted to copy local state into the new backend. After successful migration, delete the local state files:

```powershell
Remove-Item terraform.tfstate -ErrorAction SilentlyContinue
Remove-Item terraform.tfstate.backup -ErrorAction SilentlyContinue
```

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

# Day 4 — Log Analytics Workspace

## What was built

An Azure Log Analytics workspace added to the existing Terraform configuration. The workspace (`log-azure-db-sre-toolkit`) is provisioned in the same resource group as the rest of the project infrastructure, using the `PerGB2018` SKU with 30-day retention. A corresponding output was added to expose the workspace ID for reference by future resources.

## Why it was added now

Log Analytics is the centralised platform that all Azure diagnostic data flows into. It needs to exist before other resources (Azure SQL Database, Azure Functions) can be configured to send their logs and metrics to it. Adding it in Phase 1 means it is ready to receive diagnostic data the moment those resources are provisioned in Week 3, rather than having to retrofit it later.

## Key configuration decisions

- **SKU set to `PerGB2018`.** The modern pay-as-you-go tier. The free 5GB/month ingestion allowance applies automatically at this scale — no additional cost expected during development.
- **`retention_in_days` set to 30.** The minimum permitted value. Anything beyond 31 days incurs additional per-GB storage cost. For a development project, 30 days is sufficient. Production environments would set retention based on compliance requirements — regulated industries (financial services in particular) often have mandatory 90-day or longer retention requirements.
- **`daily_quota_gb` defaulted to `-1` (unlimited).** No daily cap applied. In production this would typically be set to prevent a runaway log source generating surprise costs. At this project's scale the free tier protects against cost overrun anyway, but the knob exists and is worth knowing about.

## Implicit dependency — how Terraform orders resource creation

The Log Analytics workspace references `azurerm_resource_group.main.name` for its `resource_group_name` argument. This reference is how Terraform knows the resource group must exist before it tries to create the workspace — the dependency is implicit, inferred from the attribute reference, rather than declared explicitly.

Terraform builds a dependency graph automatically from all such references and determines creation order from that graph. Explicit ordering via `depends_on` is available but should only be used when there is no natural attribute reference between resources. Relying on implicit dependencies keeps configuration cleaner and the graph more accurate.

Interview-ready answer to "how does Terraform know what order to create things in?": *"Terraform builds a dependency graph from attribute references between resources. When resource B references an attribute of resource A, Terraform infers that A must be created before B. Explicit ordering via `depends_on` is available for cases where no natural reference exists, but implicit dependencies are preferred."*

## Sensitive values in plan output

The plan output showed `primary_shared_key = (sensitive value)` and `secondary_shared_key = (sensitive value)`. These are the workspace's authentication keys, automatically generated by Azure on creation. Terraform marks them as sensitive to prevent them appearing in plain text in plan, apply, or CLI output.

Sensitive values are still written to the state file in plain text, however. This is one of the concrete reasons the remote state backend (Day 3) matters: the state file now lives in a private, access-controlled Azure Storage container rather than on the local filesystem. The workspace keys join the list of secrets already in state (alongside future SQL admin credentials) that make state-file security non-negotiable.

## Verification

Retention period verified via Azure CLI after apply:

```powershell
az monitor log-analytics workspace show `
  --resource-group rg-azure-db-sre-toolkit `
  --workspace-name log-azure-db-sre-toolkit `
  --query "retentionInDays"
```

Returns `30` — confirming Terraform applied the correct value.

In the Azure portal the SKU displays as `Pay-as-you-go`, which is the portal label for the `PerGB2018` tier. Worth knowing the label differs between Terraform and the portal — a common source of confusion when correlating config with what the portal shows.

## Day 4 reflection

Today was deliberately lighter than Day 3. The resource itself is straightforward — the value was in the concepts it surfaces rather than the complexity of the commands.

The most useful thing to absorb from today: the connection between Day 3 (remote state security) and Day 4 (sensitive values in state). These two days are not independent. The workspace shared keys being stored in state is the concrete example of why the state backend had to be hardened first. The project is being built in dependency order — not just infrastructure dependencies, but security dependencies too.

# Day 6 — Refactor and Tidy

## What was done

Code review and refactor of existing Terraform configuration. No new infrastructure added. The primary change was extracting duplicated tag blocks into a `locals` block — applying the DRY (Don't Repeat Yourself) principle to infrastructure code.

## The `locals` refactor

Before the refactor, both resource blocks contained an identical `tags` block:

```hcl
tags = {
  project    = "azure-db-sre-toolkit"
  managed_by = "terraform"
  owner      = var.owner
}
```

This was replaced with a single `locals` block defining the tags once:

```hcl
locals {
  common_tags = {
    project    = "azure-db-sre-toolkit"
    managed_by = "terraform"
    owner      = var.owner
  }
}
```

Each resource now references `tags = local.common_tags` — a single line rather than a repeated four-line block. When new resources are added in Week 3, they pick up the same tags with one line. When the project name changes, it changes in one place.

The plan after the refactor showed `0 to add, 0 to change, 0 to destroy` — confirming the refactor was purely a code change with no infrastructure impact.

## Why DRY matters in IaC

Duplicated configuration is a maintenance liability. In a larger project with dozens of resources, duplicated tag blocks mean: a naming change requires editing every resource, a reviewer has to check every block individually for consistency, and subtle drift between blocks becomes possible and hard to detect. The `locals` pattern eliminates all three risks at zero cost.

The DRY principle applies to infrastructure code exactly as it does to application code. The discipline of spotting and removing duplication before it accumulates is what separates clean, maintainable Terraform from configuration that becomes hard to manage at scale.

## Day 6 reflection

Day 6 reinforced that good engineering isn't just about making things work — it's about making them maintainable. The refactor took ten minutes and produced no visible change in Azure, but it meaningfully improved the quality of the codebase. The habit of reviewing code with fresh eyes before moving on to the next phase is worth keeping throughout the project.

# Week 2 — End of Week Reflection

## What was covered

Week 2 covered the full foundation of Terraform on Azure: core concepts (providers, state, plan vs apply), writing and applying the first configuration, setting up a production-grade remote state backend, adding the Log Analytics workspace, and a refactor pass to tidy and improve the codebase before Week 3.

## Honest reflection

The Terraform commands themselves were more straightforward than expected — the tooling is well-designed and the error messages are generally helpful. The value of the week wasn't in the commands but in understanding *why* each decision was made.

The most important gotcha of the week was the DRY principle — specifically, noticing that duplicated tag blocks across resources would become a maintenance problem at scale, and refactoring to a `locals` block before the pattern embedded itself. The general principle: don't repeat yourself in configuration code any more than in application code. Spot duplication early and remove it before it compounds.

The single thing I could explain in an interview today that I couldn't a week ago: how to build infrastructure on Azure using Terraform — from provider configuration and variable management through to remote state, dependency ordering, and code quality discipline. That's a meaningful shift from theoretical knowledge to hands-on experience.

## Going into Week 3

Week 3 adds the substantive infrastructure: Azure SQL Database (serverless), Azure Functions (consumption plan), a storage account, and diagnostic settings wiring everything into the Log Analytics workspace. The configuration will grow significantly — the discipline established this week (DRY, consistent naming, tagging via locals, clean commit messages) will matter more, not less, as complexity increases.