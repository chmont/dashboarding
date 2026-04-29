im trying to catgeroize the resouse groups into prod client facing  Nonclientfacing and all.

some subscrioptnbs like biogen has resources that are named bio-west. bio west has reourse that contain prod and uat. both are conisder client facing but i want to break that up so its esy for users to select.
amggen has amgen-prod has amg-west which only contains prod.  for this one it can be consuder amg-west-prod for easier readbality.
cddr is coniser to be 

Here's a clean, copy-paste-ready summary you can use as prompt context or reference material:

---

## HDMP Environment Types — Client-Facing Classification

### Standard Environment Set (Dev → QA → UAT → Prod)

| Abbreviation | Full Name | Client-Facing? | Description |
|---|---|---|---|
| **DEV** | Development | ❌ No | Active implementation work and initial configuration. Internal Gaine team only. |
| **QA** | Quality Assurance | ❌ No | Testing with production-like configuration. Internal Gaine validation. |
| **UAT** | User Acceptance Testing | ✅ Yes | Customer validation and training. Clients are provisioned access, conduct testing, and provide formal sign-off. |
| **PROD** | Production | ✅ Yes | Live system supporting business operations. Client end-users access and operate here. |

### Additional / Non-Standard Environments

| Abbreviation | Full Name | Client-Facing? | Description |
|---|---|---|---|
| **INT** | Integration | ❌ No | System integration testing. Internal Gaine team validates end-to-end data flows and integrations. |
| **PRE** | Preview | ✅ Yes | Shared environment for client-accessible previews and lightweight verification checks. |
| **CDDR** | Coperor Discrete Data Replicator | ❌ No | Dedicated app server running only the Orchestrator Discrete Replicator. Backend infrastructure — no user-facing interface. |

### Quick Classification Rule

| Non-Client-Facing | Client-Facing |
|---|---|
| DEV, INT, QA, CDDR | PRE (Preview), UAT, PROD |

> **Rule of thumb:** If the client/customer has login access and performs testing, validation, or operations in the environment, it's **client-facing**. If only the Gaine team works in it, it's **non-client-facing**. CDDR is a special case — it's not an environment tier but a dedicated backend server for discrete data replication, always non-client-facing regardless of which environment tier it sits within.

```kql
resources
| where type =~ "Microsoft.Compute/virtualMachines"
| extend rg = tolower(resourceGroup)
| where resourceGroup !~ "bio-west"
| where ("$category" == "All")
    or ("$category" == "Prod" and rg matches regex @"(^|[-_])(prod|production)([-_]|$)")
    or ("$category" == "Client Facing" and rg matches regex @"(^|[-_])(stage|staging|prod|production|uat|preview|pre)([-_]|$)")
    or ("$category" == "Nonclient Facing" and not(rg matches regex @"(^|[-_])(stage|staging|prod|production|uat|pre|preview)([-_]|$)"))
| project name = resourceGroup
| union (
    resources
    | where type =~ "Microsoft.Compute/virtualMachines"
    | where resourceGroup =~ "bio-west"
    | extend vmName = tolower(name)
    | where vmName matches regex @"-(app|dbp|dbp1|dbp2|dbp3)$"
    | where "$category" in ("All", "Prod", "Client Facing")
    | project name = "bio-prod"
)
| union (
    resources
    | where type =~ "Microsoft.Compute/virtualMachines"
    | where resourceGroup =~ "bio-west"
    | extend vmName = tolower(name)
    | where vmName matches regex @"-(apu|dbu)$"
    | where "$category" in ("All", "Client Facing")
    | project name = "bio-uat"
)
| distinct name
| order by name asc

// resourcecontainers
// | where type =~ "microsoft.resources/subscriptions/resourcegroups"
// | extend rg = tolower(name)
// | where ("$category" == "All")
//     or ("$category" == "Prod" and rg matches regex @"(^|[-_])(prod|production)([-_]|$)")
//     or ("$category" == "Client Facing" and rg matches regex @"(^|[-_])(stage|staging|prod|production|uat)([-_]|$)")
//     or ("$category" == "Nonclient Facing" and not(rg matches regex @"(^|[-_])(stage|staging|prod|production|uat)([-_]|$)") and rg != "bio-west")
// | project name
// | union (
//     resources
//     | where type =~ "microsoft.compute/virtualmachines"
//     | where resourceGroup =~ "bio-west"
//     | extend vmName = tolower(name)
//     | where vmName matches regex @"-(app|dbp|dbp1|dbp2|dbp3)$"
//     | where "$category" in ("All", "Prod", "Client Facing")
//     | project name = "bio-prod"
// )
// | union (
//     resources
//     | where type =~ "microsoft.compute/virtualmachines"
//     | where resourceGroup =~ "bio-west"
//     | extend vmName = tolower(name)
//     | where vmName matches regex @"-(apu|dbu)$"
//     | where "$category" in ("All", "Client Facing")
//     | project name = "bio-uat"
// )
// | distinct name
// | order by name asc
```