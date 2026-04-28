# run.ps1
# =======
# Main entry point. Pass -Action to pick what to do.
#
# Actions:
#   CreateFolder     Create client folder under Client-Homepages
#   SendDashboard    Upload one dashboard (client or shared)
#   Onboard          Create folder + upload multiple client dashboards
#   DeleteDashboard  Delete one dashboard by title
#   DeleteFolder     Delete a client folder and its dashboards
#
# Flags that can override env.base.ps1:
#   -DashboardFolder   "client" or "shared"
#   -DashboardFile     JSON filename (for single dashboard actions)
#   -DashboardFiles    List of JSON filenames (for Onboard)
#   -DashboardTitle    Dashboard title (for DeleteDashboard)
#
# Running with no -Action prints usage and exits cleanly.

param(
    [string]$Action,
    [string]$DashboardFolder,
    [string]$DashboardFile,
    [string[]]$DashboardFiles,
    [string]$DashboardTitle,
    [string]$FolderName
)

$ErrorActionPreference = "Stop"

# Make relative paths resolve against THIS script's directory
Set-Location $PSScriptRoot


# ====================================================================
# Usage banner
# ====================================================================
function Show-Usage {
    Write-Host ""
    Write-Host "Grafana Client Dashboard Automation"
    Write-Host "-----------------------------------"
    Write-Host ""
    Write-Host "USAGE:"
    Write-Host "  .\run.ps1 -Action <action> [flags]"
    Write-Host ""
    Write-Host "ACTIONS:"
    Write-Host ""
    Write-Host "  CreateFolder"
    Write-Host "    Creates the client's subfolder under Client-Homepages."
    Write-Host "    Required env: Grafana_Url, Token, Client_Name"
    Write-Host ""
    Write-Host "  SendDashboard"
    Write-Host "    Upload one dashboard. Type is controlled by -DashboardFolder."
    Write-Host "    Required env: Grafana_Url, Token, Dashboard_Folder,"
    Write-Host "                  Dashboard_File, Dashboards_Dir"
    Write-Host "    Client folder also requires: Client_Name, Subscription"
    Write-Host "    Flags: -DashboardFolder <client|shared>  -DashboardFile <file>"
    Write-Host ""
    Write-Host "  Onboard"
    Write-Host "    Create the client folder, then upload a set of client dashboards."
    Write-Host "    Required env: Grafana_Url, Token, Client_Name, Subscription,"
    Write-Host "                  Dashboards_Dir"
    Write-Host "    Flags: -DashboardFiles <file1.json,file2.json,...>"
    Write-Host ""
    Write-Host "  DeleteDashboard"
    Write-Host "    Delete one dashboard by its title. Prompts for confirmation."
    Write-Host "    Just pass the title - the script finds it and shows you its folder"
    Write-Host "    so you can confirm. If multiple dashboards share the title, you pick."
    Write-Host "    Required env: Grafana_Url, Token, Dashboard_Title"
    Write-Host "    Flags: -DashboardTitle <title>"
    Write-Host ""
    Write-Host "  DeleteFolder"
    Write-Host "    Delete any folder in Grafana (and all dashboards inside). Prompts for confirmation."
    Write-Host "    Just pass the folder NAME - the script finds it and shows you its parent"
    Write-Host "    folder so you can confirm you've got the right one."
    Write-Host "    Required env: Grafana_Url, Token, Folder_Name"
    Write-Host "    Flags: -FolderName <name>  (e.g. 'Acme Corp' or 'Client-Dashboards')"
    Write-Host ""
    Write-Host "EXAMPLES:"
    Write-Host "  .\run.ps1 -Action CreateFolder"
    Write-Host "  .\run.ps1 -Action SendDashboard -DashboardFolder client -DashboardFile my-home.json"
    Write-Host "  .\run.ps1 -Action SendDashboard -DashboardFolder shared -DashboardFile overview.json"
    Write-Host "  .\run.ps1 -Action Onboard -DashboardFiles my-home.json,extras.json"
    Write-Host "  .\run.ps1 -Action DeleteDashboard -DashboardTitle `"Acme Home`""
    Write-Host "  .\run.ps1 -Action DeleteFolder -FolderName `"Acme Corp`""
    Write-Host ""
    Write-Host "Edit env.base.ps1 to set environment variables."
    Write-Host ""
}


# ====================================================================
# Step 1 - Validate -Action
# ====================================================================
$validActions = @(
    "CreateFolder",
    "SendDashboard",
    "Onboard",
    "DeleteDashboard",
    "DeleteFolder"
)

if ([string]::IsNullOrWhiteSpace($Action)) {
    Show-Usage
    return
}

if ($validActions -notcontains $Action) {
    Write-Host ""
    Write-Host "ERROR: '$Action' is not a valid action."
    Show-Usage
    return
}


# ====================================================================
# Step 2 - Load environment variables
# ====================================================================
Write-Host ""
Write-Host "==== Grafana automation : $Action ===="
Write-Host ""
Write-Host "Loading environment from env.base.ps1..."
. .\env.base.ps1


# ====================================================================
# Step 3 - Apply command-line overrides
# ====================================================================
# Command-line flags beat env.base.ps1 values for this run only.

if (-not [string]::IsNullOrWhiteSpace($DashboardFolder)) {
    $env:Dashboard_Folder = $DashboardFolder.Trim().ToLower()
    Write-Host "  Override: Dashboard_Folder = $env:Dashboard_Folder"
}
if (-not [string]::IsNullOrWhiteSpace($DashboardFile)) {
    $env:Dashboard_File = $DashboardFile.Trim()
    Write-Host "  Override: Dashboard_File = $env:Dashboard_File"
}
if (-not [string]::IsNullOrWhiteSpace($DashboardTitle)) {
    $env:Dashboard_Title = $DashboardTitle.Trim()
    Write-Host "  Override: Dashboard_Title = $env:Dashboard_Title"
}
if (-not [string]::IsNullOrWhiteSpace($FolderName)) {
    $env:Folder_Name = $FolderName.Trim()
    Write-Host "  Override: Folder_Name = $env:Folder_Name"
}


# ====================================================================
# Step 4 - Build config
# ====================================================================
Write-Host "Building config..."
$config = . .\config.ps1


# ====================================================================
# Step 5 - Dispatch to the chosen action
# ====================================================================
Write-Host "Dispatching: $Action"
Write-Host ""

switch ($Action) {
    "CreateFolder"    { . .\create-folder.ps1    -Config $config }
    "SendDashboard"   { . .\send-dashboard.ps1   -Config $config }
    "Onboard"         { . .\onboard.ps1          -Config $config -DashboardFiles $DashboardFiles }
    "DeleteDashboard" { . .\delete-dashboard.ps1 -Config $config }
    "DeleteFolder"    { . .\delete-folder.ps1    -Config $config }
}

Write-Host ""
Write-Host "==== Done ===="
Write-Host ""
