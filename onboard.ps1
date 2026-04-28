# onboard.ps1
# ===========
# Full onboarding flow for a new client:
#   1. Create the client subfolder under Client-Homepages
#   2. For each file in -DashboardFiles, upload it as a client dashboard
#
# Shared dashboards are NOT part of onboarding. They're deployed once
# globally via:
#   .\run.ps1 -Action SendDashboard -DashboardFolder shared -DashboardFile <file>
#
# USAGE:
#   .\run.ps1 -Action Onboard -DashboardFiles home.json,extras.json
#
# If -DashboardFiles is omitted, falls back to $env:Dashboard_File as
# a single-file onboard.

param(
    [Parameter(Mandatory = $true)]
    [hashtable]$Config,

    # List of JSON filenames (found in dashboards/templates/client/)
    [string[]]$DashboardFiles
)

$ErrorActionPreference = "Stop"


# ====================================================================
# Step 1 - Determine the list of files to upload
# ====================================================================
if ($null -eq $DashboardFiles -or $DashboardFiles.Count -eq 0) {
    if (-not [string]::IsNullOrWhiteSpace($env:Dashboard_File)) {
        $DashboardFiles = @($env:Dashboard_File)
        Write-Host "No -DashboardFiles passed; using Dashboard_File from env: $env:Dashboard_File"
    } else {
        throw "No dashboards specified. Pass -DashboardFiles file1.json,file2.json or set Dashboard_File in env.base.ps1."
    }
}


# ====================================================================
# Step 2 - Validate shared prerequisites once
# ====================================================================
if ([string]::IsNullOrWhiteSpace($Config.ClientName)) {
    throw "Client_Name is missing. Required for onboarding."
}
if ([string]::IsNullOrWhiteSpace($Config.SubscriptionId)) {
    throw "Subscription is missing. Required for onboarding client dashboards."
}
if ([string]::IsNullOrWhiteSpace($Config.DashboardsDir)) {
    throw "Dashboards_Dir is missing. Set it in env.base.ps1."
}


# ====================================================================
# Step 3 - Show the plan before doing anything
# ====================================================================
Write-Host ""
Write-Host "Onboarding plan"
Write-Host "---------------"
Write-Host "  Client:        $($Config.ClientName)"
Write-Host "  Subscription:  $($Config.SubscriptionId)"
Write-Host "  Folder:        $($Config.ClientParentFolder) / $($Config.ClientName)"
Write-Host "  Dashboards:    $($DashboardFiles -join ', ')"
Write-Host ""


# ====================================================================
# Step 4 - Create the client folder
# ====================================================================
# On success, create-folder.ps1 writes the folder UID back to $Config
# as ClientFolderUid. If it fails, the Stop error preference bubbles
# up and we never start uploading.

Write-Host "[1/2] Creating client folder..."
Write-Host ""
. .\create-folder.ps1 -Config $Config
Write-Host ""


# ====================================================================
# Step 5 - Upload each dashboard
# ====================================================================
# For each file we:
#   - set Config.DashboardFolder = "client" (onboard only does client)
#   - set Config.DashboardFile and rebuild the associated paths
#   - delegate to send-dashboard.ps1

$totalFiles  = $DashboardFiles.Count
$currentIndex = 0

foreach ($rawFile in $DashboardFiles) {
    $currentIndex++
    $fileName = $rawFile.Trim()

    if ([string]::IsNullOrWhiteSpace($fileName)) {
        Write-Host "  [skip] Empty filename at position $currentIndex"
        continue
    }

    Write-Host "[2/2] Uploading dashboard $currentIndex of ${totalFiles}: $fileName"
    Write-Host ""

    # --- Update the per-dashboard fields on the shared config --------
    $Config.DashboardFolder = "client"
    $Config.DashboardFile   = $fileName

    # Rebuild paths that depend on the filename
    $safeClientName = ($Config.ClientName.ToLower().Trim() -replace '[^a-z0-9]+', '-').Trim('-')

    $Config.TemplateFilePath = Join-Path $Config.TemplatesClientDir $fileName
    $Config.OutputFilePath   = Join-Path $Config.OutputDir          "$safeClientName-$fileName"
    $Config.PayloadFilePath  = Join-Path $Config.PayloadsDir        "$safeClientName-$fileName.payload.json"

    # Keep env vars in sync for update_sub_var.py (invoked by send-dashboard.ps1)
    $env:Dashboard_Folder = "client"
    $env:Dashboard_File   = $fileName

    # --- Delegate the upload -----------------------------------------
    try {
        . .\send-dashboard.ps1 -Config $Config
    }
    catch {
        Write-Host ""
        Write-Host "Onboarding stopped: dashboard '$fileName' failed to upload."
        Write-Host "  Error: $($_.Exception.Message)"
        throw
    }

    Write-Host ""
}


# ====================================================================
# Step 6 - Summary
# ====================================================================
Write-Host "Onboarding complete for '$($Config.ClientName)'."
Write-Host "  Folder:     $($Config.ClientParentFolder) / $($Config.ClientName)"
Write-Host "  Uploaded:   $($DashboardFiles -join ', ')"
