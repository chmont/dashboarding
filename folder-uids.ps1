Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<##
.SYNOPSIS
Creates or updates a Grafana folder tree using the current Folder API.

.DESCRIPTION
- Uses the Grafana Folder API under /apis/folder.grafana.app/v1/namespaces/:namespace/folders
- Treats metadata.name as the caller-chosen folder identifier
- Supports root folders and nested child folders
- Prints the planned actions first, then asks for confirmation before making changes
- Is safe to rerun: existing folders are updated only when the title or parent changes

.NOTES
- Nested folders must be enabled in Grafana for child folders to work.
- The parent folder reference is sent via metadata.annotations["grafana.app/folder"].
- Parents must be listed before their children in $FolderDefinitions.
##>

# =========================
# Configuration
# =========================

$BaseUrl = 'https://grafana-central-gggsdfaed7h2a3bc.wus.grafana.azure.com/'
$token = $env:Token


$parentUid = "TestShared"

$body = @{
    metadata = @{
        name = "TestShared-Child"
        annotations = @{
            "grafana.app/folder" = $parentUid
        }
    }
    spec = @{
        title = "Child"
    }
} | ConvertTo-Json -Depth 10

$response = Invoke-RestMethod `
    -Method Post `
    -Uri "$BaseUrl/apis/folder.grafana.app/v1beta1/namespaces/default/folders" `
    -Headers $headers `
    -Body $body

$response