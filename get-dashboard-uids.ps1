# get-dashboard-uids.ps1
# ======================
# Helper used by delete-dashboard.ps1 to locate a dashboard by title.
#
# RESOLUTION:
#   - Config.DashboardFolder = "client"
#       search inside Client-Homepages / {Client_Name}
#       match on title == Config.DashboardTitle (exact)
#
#   - Config.DashboardFolder = "shared"
#       search inside Shared / Client-Dashboards
#       match on title == Config.DashboardTitle (exact)
#
# RETURNS:
#   [pscustomobject] with:
#     uid    - dashboard UID (empty if not found)
#     title  - exact title Grafana has on record (empty if not found)
#     folder - human-readable folder path (always populated)

param(
    [Parameter(Mandatory = $true)]
    [hashtable]$Config
)

$ErrorActionPreference = "Stop"


# ====================================================================
# Step 1 - Validate inputs
# ====================================================================
if ([string]::IsNullOrWhiteSpace($Config.DashboardFolder)) {
    throw "Dashboard_Folder is missing. Set it in env.base.ps1 or pass -DashboardFolder (client|shared)."
}
if ([string]::IsNullOrWhiteSpace($Config.DashboardTitle)) {
    throw "Dashboard_Title is missing. Set it in env.base.ps1 or pass -DashboardTitle."
}


# ====================================================================
# HTTP headers
# ====================================================================
$headers = @{
    Authorization = "Bearer $($Config.Token)"
    Accept        = "application/json"
}


# ====================================================================
# Step 2 - Resolve the target Grafana folder UID
# ====================================================================
$targetFolderUid   = ""
$targetFolderLabel = ""

if ($Config.DashboardFolder -eq "client") {

    if ([string]::IsNullOrWhiteSpace($Config.ClientName)) {
        throw "Client_Name is missing. Required when deleting from a client folder."
    }

    $targetFolderLabel = "$($Config.ClientParentFolder) / $($Config.ClientName)"

    # Find Client-Homepages
    $encodedParent   = [uri]::EscapeDataString($Config.ClientParentFolder)
    $parentSearchUri = "$($Config.GrafanaUrl)/api/search?type=dash-folder&query=$encodedParent"
    $parentResults   = Invoke-RestMethod -Method Get -Uri $parentSearchUri -Headers $headers
    $parentFolder    = $parentResults | Where-Object { $_.title -eq $Config.ClientParentFolder }

    if ($null -eq $parentFolder) {
        throw "Parent folder '$($Config.ClientParentFolder)' not found in Grafana."
    }
    $parentFolderUid = @($parentFolder)[0].uid

    # Find client subfolder
    $encodedClient   = [uri]::EscapeDataString($Config.ClientName)
    $clientSearchUri = "$($Config.GrafanaUrl)/api/search?type=dash-folder&query=$encodedClient&folderUIDs=$parentFolderUid"
    $clientResults   = Invoke-RestMethod -Method Get -Uri $clientSearchUri -Headers $headers
    $clientFolder    = $clientResults | Where-Object { $_.title -eq $Config.ClientName }

    if ($null -eq $clientFolder) {
        throw "Client folder '$($Config.ClientName)' not found under '$($Config.ClientParentFolder)'."
    }

    $targetFolderUid = @($clientFolder)[0].uid

} else {

    $targetFolderLabel = "$($Config.SharedParentFolder) / $($Config.SharedChildFolder)"

    # Find Shared
    $encodedSharedParent = [uri]::EscapeDataString($Config.SharedParentFolder)
    $sharedParentUri     = "$($Config.GrafanaUrl)/api/search?type=dash-folder&query=$encodedSharedParent"
    $sharedParentResults = Invoke-RestMethod -Method Get -Uri $sharedParentUri -Headers $headers
    $sharedParent        = $sharedParentResults | Where-Object { $_.title -eq $Config.SharedParentFolder }

    if ($null -eq $sharedParent) {
        throw "Parent folder '$($Config.SharedParentFolder)' not found in Grafana."
    }
    $sharedParentUid = @($sharedParent)[0].uid

    # Find Client-Dashboards
    $encodedSharedChild = [uri]::EscapeDataString($Config.SharedChildFolder)
    $sharedChildUri     = "$($Config.GrafanaUrl)/api/search?type=dash-folder&query=$encodedSharedChild&folderUIDs=$sharedParentUid"
    $sharedChildResults = Invoke-RestMethod -Method Get -Uri $sharedChildUri -Headers $headers
    $sharedChild        = $sharedChildResults | Where-Object { $_.title -eq $Config.SharedChildFolder }

    if ($null -eq $sharedChild) {
        throw "Folder '$($Config.SharedChildFolder)' not found under '$($Config.SharedParentFolder)'."
    }

    $targetFolderUid = @($sharedChild)[0].uid
}


# ====================================================================
# Step 3 - Search for the dashboard inside the resolved folder
# ====================================================================
$expectedTitle = $Config.DashboardTitle

Write-Host "Looking for dashboard '$expectedTitle' in $targetFolderLabel..."

$encodedTitle  = [uri]::EscapeDataString($expectedTitle)
$searchUri     = "$($Config.GrafanaUrl)/api/search?type=dash-db&query=$encodedTitle&folderUIDs=$targetFolderUid"
$searchResults = Invoke-RestMethod -Method Get -Uri $searchUri -Headers $headers

# Exact title match scoped to the target folder
$matched = $searchResults | Where-Object {
    $_.title     -eq $expectedTitle -and
    $_.folderUid -eq $targetFolderUid
}

$foundUid   = ""
$foundTitle = ""

if ($null -ne $matched) {
    $foundUid   = @($matched)[0].uid
    $foundTitle = @($matched)[0].title

    Write-Host "  Found:"
    Write-Host "    Title: $foundTitle"
    Write-Host "    UID:   $foundUid"
} else {
    Write-Host "  No dashboard with that title in that folder."
}


# ====================================================================
# Step 4 - Return
# ====================================================================
[pscustomobject]@{
    uid    = $foundUid
    title  = $foundTitle
    folder = $targetFolderLabel
}
