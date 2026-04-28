# send-dashboard.ps1
# ==================
# Uploads ONE dashboard to Grafana.
#
# Behavior depends on $Config.DashboardFolder:
#
#   "client"
#     - Reads from: dashboards/templates/client/{Dashboard_File}
#     - Runs update_sub_var.py to strip UID, reset id/version,
#       and stamp Client_Name + Subscription into the 'sub' variable
#     - Uploads to: Client-Homepages / {Client_Name}
#     - Title stays as whatever is in the JSON file
#
#   "shared"
#     - Reads from: dashboards/templates/shared/{Dashboard_File}
#     - Uploads AS-IS - UID preserved, nothing modified
#     - Uploads to: Shared / Client-Dashboards
#
# Before uploading, the user is shown the target and asked to
# confirm. If a dashboard with the same title already exists in
# the target folder, they're asked whether to overwrite.

param(
    [Parameter(Mandatory = $true)]
    [hashtable]$Config
)

$ErrorActionPreference = "Stop"


# ====================================================================
# Step 1 - Validate common inputs
# ====================================================================
if ([string]::IsNullOrWhiteSpace($Config.DashboardFolder)) {
    throw "Dashboard_Folder is missing. Set it in env.base.ps1 or pass -DashboardFolder (client|shared)."
}
if ([string]::IsNullOrWhiteSpace($Config.DashboardFile)) {
    throw "Dashboard_File is missing. Set it in env.base.ps1 or pass -DashboardFile."
}
if ([string]::IsNullOrWhiteSpace($Config.DashboardsDir)) {
    throw "Dashboards_Dir is missing. Set it in env.base.ps1."
}
if ([string]::IsNullOrWhiteSpace($Config.TemplateFilePath)) {
    throw "Could not build template file path. Check Dashboards_Dir, Dashboard_Folder, Dashboard_File."
}
if (-not (Test-Path $Config.TemplateFilePath)) {
    throw "Template file not found: $($Config.TemplateFilePath)"
}


# ====================================================================
# Shared HTTP headers
# ====================================================================
$headersGet = @{
    Authorization = "Bearer $($Config.Token)"
    Accept        = "application/json"
}


# ====================================================================
# Step 2 - Peek at the template title for the confirmation prompt
# ====================================================================
# We read the JSON now so we can show the user what title will end
# up in Grafana. For client uploads this is also the title used -
# update_sub_var.py doesn't change it.

Write-Host "Reading template: $($Config.TemplateFilePath)"
$rawTemplateJson = Get-Content -Raw -Path $Config.TemplateFilePath
$templateObject  = $rawTemplateJson | ConvertFrom-Json

$templateTitle = $templateObject.title
if ([string]::IsNullOrWhiteSpace($templateTitle)) {
    throw "Template JSON has no 'title' field: $($Config.TemplateFilePath)"
}


# ====================================================================
# Step 3 - Resolve the target Grafana folder UID
# ====================================================================
# For "client": Client-Homepages / {Client_Name}
# For "shared": Shared / Client-Dashboards

$targetFolderLabel = ""   # human-readable folder path (for display)
$targetFolderUid   = ""   # folder UID used by the upload API

if ($Config.DashboardFolder -eq "client") {

    if ([string]::IsNullOrWhiteSpace($Config.ClientName)) {
        throw "Client_Name is missing. Required for client folder uploads."
    }
    if ([string]::IsNullOrWhiteSpace($Config.SubscriptionId)) {
        throw "Subscription is missing. Required for client folder uploads."
    }

    $targetFolderLabel = "$($Config.ClientParentFolder) / $($Config.ClientName)"

    # Find Client-Homepages (parent)
    $encodedParent   = [uri]::EscapeDataString($Config.ClientParentFolder)
    $parentSearchUri = "$($Config.GrafanaUrl)/api/search?type=dash-folder&query=$encodedParent"
    $parentResults   = Invoke-RestMethod -Method Get -Uri $parentSearchUri -Headers $headersGet
    $parentFolder    = $parentResults | Where-Object { $_.title -eq $Config.ClientParentFolder }

    if ($null -eq $parentFolder) {
        throw "Parent folder '$($Config.ClientParentFolder)' not found in Grafana. Create it first."
    }
    $parentFolderUid = @($parentFolder)[0].uid

    # Find the client subfolder inside that parent
    $encodedClient   = [uri]::EscapeDataString($Config.ClientName)
    $clientSearchUri = "$($Config.GrafanaUrl)/api/search?type=dash-folder&query=$encodedClient&folderUIDs=$parentFolderUid"
    $clientResults   = Invoke-RestMethod -Method Get -Uri $clientSearchUri -Headers $headersGet
    $clientFolder    = $clientResults | Where-Object { $_.title -eq $Config.ClientName }

    if ($null -eq $clientFolder) {
        throw "Client folder '$($Config.ClientName)' not found under '$($Config.ClientParentFolder)'. Run:  .\run.ps1 -Action CreateFolder  first."
    }

    $targetFolderUid = @($clientFolder)[0].uid
    $Config.ClientFolderUid = $targetFolderUid

} else {
    # Shared folder
    $targetFolderLabel = "$($Config.SharedParentFolder) / $($Config.SharedChildFolder)"

    # Find Shared (parent)
    $encodedSharedParent = [uri]::EscapeDataString($Config.SharedParentFolder)
    $sharedParentUri     = "$($Config.GrafanaUrl)/api/search?type=dash-folder&query=$encodedSharedParent"
    $sharedParentResults = Invoke-RestMethod -Method Get -Uri $sharedParentUri -Headers $headersGet
    $sharedParent        = $sharedParentResults | Where-Object { $_.title -eq $Config.SharedParentFolder }

    if ($null -eq $sharedParent) {
        throw "Parent folder '$($Config.SharedParentFolder)' not found in Grafana. Create it first."
    }
    $sharedParentUid = @($sharedParent)[0].uid

    # Find Client-Dashboards (child of Shared)
    $encodedSharedChild = [uri]::EscapeDataString($Config.SharedChildFolder)
    $sharedChildUri     = "$($Config.GrafanaUrl)/api/search?type=dash-folder&query=$encodedSharedChild&folderUIDs=$sharedParentUid"
    $sharedChildResults = Invoke-RestMethod -Method Get -Uri $sharedChildUri -Headers $headersGet
    $sharedChild        = $sharedChildResults | Where-Object { $_.title -eq $Config.SharedChildFolder }

    if ($null -eq $sharedChild) {
        throw "Folder '$($Config.SharedChildFolder)' not found under '$($Config.SharedParentFolder)'. Create it first."
    }

    $targetFolderUid = @($sharedChild)[0].uid
}


# ====================================================================
# Step 4 - Confirm with the user before doing anything destructive
# ====================================================================
# Since there's no filename convention, we show the user exactly
# what file + title + destination we're about to use and ask them
# to verify. Loops until valid y/n is entered.

Write-Host ""
Write-Host "About to upload:"
Write-Host "  Local file:     $($Config.TemplateFilePath)"
Write-Host "  Dashboard type: $($Config.DashboardFolder)"
Write-Host "  Title in JSON:  $templateTitle"
Write-Host "  Target folder:  $targetFolderLabel"
if ($Config.DashboardFolder -eq "client") {
    Write-Host "  Subscription:   $($Config.SubscriptionId)"
}
Write-Host ""

$confirmed = $false
do {
    $answer = (Read-Host "Is this correct? (y/n)").Trim()

    if ($answer -match '^(?i)(y|yes)$') {
        $confirmed  = $true
        $validInput = $true
    }
    elseif ($answer -match '^(?i)(n|no)$') {
        $confirmed  = $false
        $validInput = $true
    }
    else {
        Write-Host "  Please enter y, yes, n, or no."
        $validInput = $false
    }
} until ($validInput)

if (-not $confirmed) {
    Write-Host "Cancelled. Nothing was uploaded."
    return
}


# ====================================================================
# Step 5 - Prepare the dashboard object for upload
# ====================================================================
# Client path: run Python to update the sub variable + reset identity
# Shared path: use the template JSON directly, no modifications

$dashboardObject = $null

if ($Config.DashboardFolder -eq "client") {

    # Ensure the output and payloads directories exist
    foreach ($dir in @($Config.OutputDir, $Config.PayloadsDir)) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Host "  Created directory: $dir"
        }
    }

    Write-Host "Generating client-ready copy via update_sub_var.py..."

    # Python script reads these env vars and writes the customized JSON
    $env:Source_Path = $Config.TemplateFilePath
    $env:Output_Path = $Config.OutputFilePath

    python .\update_sub_var.py

    if ($LASTEXITCODE -ne 0) {
        throw "update_sub_var.py failed with exit code $LASTEXITCODE"
    }

    # Load the generated copy
    $dashboardObject = Get-Content -Raw -Path $Config.OutputFilePath | ConvertFrom-Json

} else {
    # Shared: use the template as-is, UID preserved.
    #
    # We do null out `id` though - it's an instance-specific numeric
    # value that Grafana uses internally. A dashboard exported from
    # one Grafana instance will have an `id` that likely doesn't
    # exist in your target instance, which causes Grafana to return
    # 404 "Dashboard not found" on upload.
    #
    # Nulling `id` tells Grafana "this is a new dashboard (or match
    # by UID if overwrite=true)". The UID stays exactly the same so
    # homepage links remain stable.
    Write-Host "Using shared template (UID preserved, id nulled)"
    $dashboardObject = $templateObject

    if ($dashboardObject.PSObject.Properties.Name -contains 'id') {
        $dashboardObject.id = $null
    }
}


# ====================================================================
# Step 6 - Strip Grafana export-only fields
# ====================================================================
# When a dashboard is exported through the Grafana UI, it may include
# __inputs, __elements, __requires - those break the upload API.

foreach ($exportField in @('__inputs', '__elements', '__requires')) {
    if ($dashboardObject.PSObject.Properties.Name -contains $exportField) {
        $dashboardObject.PSObject.Properties.Remove($exportField)
    }
}


# ====================================================================
# Step 7 - Check for an existing dashboard in the target folder
# ====================================================================
# Uses the title we're about to upload with. For client uploads the
# title equals the JSON's title (Python didn't change it). For shared
# it's also the JSON's title.

$uploadTitle = $dashboardObject.title

Write-Host "Checking whether '$uploadTitle' already exists in the target folder..."

$encodedTitle  = [uri]::EscapeDataString($uploadTitle)
$searchDashUri = "$($Config.GrafanaUrl)/api/search?type=dash-db&query=$encodedTitle&folderUIDs=$targetFolderUid"
$searchResults = Invoke-RestMethod -Method Get -Uri $searchDashUri -Headers $headersGet

$existingDashboard = $searchResults | Where-Object {
    $_.title     -eq $uploadTitle -and
    $_.folderUid -eq $targetFolderUid
}

$shouldOverwrite = $false
if ($null -ne $existingDashboard) {
    $overwriteConfirmed = $false
    do {
        $answer = (Read-Host "A dashboard titled '$uploadTitle' already exists here. Overwrite? (y/n)").Trim()

        if ($answer -match '^(?i)(y|yes)$') {
            $overwriteConfirmed = $true
            $validInput         = $true
        }
        elseif ($answer -match '^(?i)(n|no)$') {
            $overwriteConfirmed = $false
            $validInput         = $true
        }
        else {
            Write-Host "  Please enter y, yes, n, or no."
            $validInput = $false
        }
    } until ($validInput)

    if (-not $overwriteConfirmed) {
        Write-Host "Cancelled. Existing dashboard was not overwritten."
        return
    }
    $shouldOverwrite = $true
}


# ====================================================================
# Step 8 - Build the upload body and save it for debugging
# ====================================================================
# POST /api/dashboards/db expects:
#   dashboard   - the dashboard object
#   folderUid   - target folder
#   overwrite   - replace existing with same UID/title
#   message     - commit message (shows in Grafana's version history)
#
# -Depth 100 is important. The default depth is 2, which silently
# truncates the deeply nested panel/target/query structure.

$uploadBodyObject = @{
    dashboard = $dashboardObject
    folderUid = $targetFolderUid
    overwrite = $shouldOverwrite
    message   = "Automated deployment via run.ps1 ($($Config.DashboardFolder))"
}

$uploadBody = $uploadBodyObject | ConvertTo-Json -Depth 100

# Save the request body for debugging
if (-not [string]::IsNullOrWhiteSpace($Config.PayloadsDir)) {
    if (-not (Test-Path $Config.PayloadsDir)) {
        New-Item -ItemType Directory -Path $Config.PayloadsDir -Force | Out-Null
    }
    if (-not [string]::IsNullOrWhiteSpace($Config.PayloadFilePath)) {
        $uploadBody | Set-Content -Path $Config.PayloadFilePath -Encoding UTF8
        Write-Host "  Debug: saved payload to $($Config.PayloadFilePath)"
    }
}


# ====================================================================
# Step 9 - Upload
# ====================================================================
$uploadUri = "$($Config.GrafanaUrl)/api/dashboards/db"

try {
    $response = Invoke-RestMethod `
        -Method      Post `
        -Uri         $uploadUri `
        -Headers     $headersGet `
        -Body        $uploadBody `
        -ContentType "application/json; charset=utf-8"

    Write-Host ""
    Write-Host "Dashboard uploaded: $uploadTitle"
    if ($response.url) { Write-Host "  URL: $($Config.GrafanaUrl)$($response.url)" }
    if ($response.uid) { Write-Host "  UID: $($response.uid)" }
}
catch {
    Write-Host "Upload failed."

    # Try to pull a status code. Works on both PowerShell 5 and 7+.
    $statusCode = $null
    if ($null -ne $_.Exception.Response -and $null -ne $_.Exception.Response.StatusCode) {
        $statusCode = $_.Exception.Response.StatusCode
    }

    # Try to pull the response body. PowerShell 5 and 7 expose this
    # differently, so we try both.
    $responseBody = $null

    # PowerShell 7+ puts the response body in ErrorDetails.Message
    if ($null -ne $_.ErrorDetails -and -not [string]::IsNullOrWhiteSpace($_.ErrorDetails.Message)) {
        $responseBody = $_.ErrorDetails.Message
    }
    # PowerShell 5 fallback: read the WebResponse stream
    elseif ($null -ne $_.Exception.Response -and `
            ($_.Exception.Response.PSObject.Methods.Name -contains 'GetResponseStream')) {
        try {
            $stream = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($stream)
            $responseBody = $reader.ReadToEnd()
        } catch {
            # If even the fallback fails, leave body null
        }
    }

    if ($null -ne $statusCode)                           { Write-Host "  Status: $statusCode" }
    if (-not [string]::IsNullOrWhiteSpace($responseBody)) { Write-Host "  Body:   $responseBody" }

    if (-not [string]::IsNullOrWhiteSpace($Config.PayloadFilePath)) {
        Write-Host "  Saved payload (for debugging): $($Config.PayloadFilePath)"
    }

    throw
}
