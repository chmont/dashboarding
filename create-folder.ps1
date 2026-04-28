# create-folder.ps1
# =================
# Creates the client's subfolder inside Client-Homepages.
#
# STEPS:
#   1. Look up parent folder (Client-Homepages) - must already exist.
#   2. Check if the client subfolder already exists.
#        - If yes: re-use its UID, don't recreate.
#        - If no:  POST /api/folders to create it inside the parent.
#
# The resolved folder UID is written back into the config hashtable
# as $Config.ClientFolderUid so other scripts (send-dashboard.ps1,
# onboard.ps1) can re-use it.

param(
    [Parameter(Mandatory = $true)]
    [hashtable]$Config
)

$ErrorActionPreference = "Stop"


# ====================================================================
# Step 1 - Validate required inputs
# ====================================================================
if ([string]::IsNullOrWhiteSpace($Config.ClientName)) {
    throw "Client_Name is missing. Required to name the client subfolder."
}


# ====================================================================
# HTTP headers
# ====================================================================
$headersGet = @{
    Authorization = "Bearer $($Config.Token)"
    Accept        = "application/json"
}
$headersPost = @{
    Authorization  = "Bearer $($Config.Token)"
    Accept         = "application/json"
    "Content-Type" = "application/json"
}


# ====================================================================
# Step 2 - Find the parent folder (Client-Homepages)
# ====================================================================
$parentFolderName = $Config.ClientParentFolder
Write-Host "Looking for parent folder: '$parentFolderName' ..."

$encodedParentName = [uri]::EscapeDataString($parentFolderName)
$searchParentUri   = "$($Config.GrafanaUrl)/api/search?type=dash-folder&query=$encodedParentName"

$parentSearchResults = Invoke-RestMethod -Method Get -Uri $searchParentUri -Headers $headersGet

# /api/search is fuzzy - filter for exact title match
$parentFolder = $parentSearchResults | Where-Object { $_.title -eq $parentFolderName }

if ($null -eq $parentFolder) {
    throw "Parent folder '$parentFolderName' not found in Grafana. Create it manually first."
}

# @() wrap ensures [0] works whether we got 1 match or many
$parentFolderUid = @($parentFolder)[0].uid
Write-Host "  Found parent folder (uid: $parentFolderUid)"


# ====================================================================
# Step 3 - Check if client subfolder already exists
# ====================================================================
# folderUIDs filter scopes the search to inside the parent, so a folder
# with the same name under a different parent won't trigger a false match.

$clientFolderName = $Config.ClientName
Write-Host "Checking for existing client subfolder: '$clientFolderName' ..."

$encodedClientName = [uri]::EscapeDataString($clientFolderName)
$searchClientUri   = "$($Config.GrafanaUrl)/api/search?type=dash-folder&query=$encodedClientName&folderUIDs=$parentFolderUid"

$clientSearchResults = Invoke-RestMethod -Method Get -Uri $searchClientUri -Headers $headersGet

$existingClientFolder = $clientSearchResults | Where-Object { $_.title -eq $clientFolderName }

if ($null -ne $existingClientFolder) {
    $existingFolderUid = @($existingClientFolder)[0].uid

    Write-Host "  Folder already exists (uid: $existingFolderUid)"
    Write-Host "  Location: $parentFolderName / $clientFolderName"

    $Config.ClientFolderUid = $existingFolderUid
    return
}


# ====================================================================
# Step 4 - Create the client subfolder
# ====================================================================
Write-Host "Creating subfolder '$clientFolderName' under '$parentFolderName' ..."

$createFolderUri = "$($Config.GrafanaUrl)/api/folders"
$createFolderBody = @{
    title     = $clientFolderName
    parentUid = $parentFolderUid
} | ConvertTo-Json -Depth 10

$createdFolder = Invoke-RestMethod `
    -Method  Post `
    -Uri     $createFolderUri `
    -Headers $headersPost `
    -Body    $createFolderBody

Write-Host "  Created folder '$($createdFolder.title)' (uid: $($createdFolder.uid))"
Write-Host "  Location: $parentFolderName / $($createdFolder.title)"

$Config.ClientFolderUid = $createdFolder.uid
