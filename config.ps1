# config.ps1
# ==========
# Reads env.base.ps1 values and returns a config hashtable.
#
# Each action script receives this hashtable. Only the three
# universal values are validated here:
#   - Grafana_Url
#   - Token
#   - Dashboard_Folder (must be "client" or "shared" if set)
#
# Everything else is optional at the config level. Action scripts
# validate their own specific requirements.
#
# HOW IT'S CALLED:
#   $config = . .\config.ps1
#   (dot-source; the last expression is returned as the value)


# ====================================================================
# Step 1 - Read required values
# ====================================================================
$grafanaUrl = $env:Grafana_Url
$token      = $env:Token

if ([string]::IsNullOrWhiteSpace($grafanaUrl)) {
    throw "Grafana_Url is missing. Set it in env.base.ps1."
}
if ([string]::IsNullOrWhiteSpace($token)) {
    throw "Token is missing. Set it in env.base.ps1."
}

# TrimEnd removes any trailing slash so we don't produce double-slash URLs
$grafanaUrl = $grafanaUrl.TrimEnd('/')


# ====================================================================
# Step 2 - Read and normalize the dashboard folder type
# ====================================================================
# Lowercased so comparisons elsewhere are case-insensitive.
# Valid values: "client", "shared", or empty.

$dashboardFolder = if ([string]::IsNullOrWhiteSpace($env:Dashboard_Folder)) {
    ""
} else {
    $env:Dashboard_Folder.Trim().ToLower()
}

if ($dashboardFolder -ne "" -and $dashboardFolder -ne "client" -and $dashboardFolder -ne "shared") {
    throw "Dashboard_Folder '$dashboardFolder' is invalid. Must be 'client' or 'shared'."
}


# ====================================================================
# Step 3 - Read remaining optional values
# ====================================================================
$dashboardFile   = $env:Dashboard_File
$dashboardTitle  = $env:Dashboard_Title
$dashboardsDir   = $env:Dashboards_Dir
$clientName      = $env:Client_Name
$subscriptionId  = $env:Subscription
$folderName      = $env:Folder_Name


# ====================================================================
# Step 4 - Build local file paths based on Dashboard_Folder
# ====================================================================
# If Dashboards_Dir or Dashboard_File are missing, the paths are
# left empty. Action scripts that need them will complain.

$templatesBaseDir    = ""
$templatesClientDir  = ""
$templatesSharedDir  = ""
$outputDir           = ""
$payloadsDir         = ""
$templateFilePath    = ""
$outputFilePath      = ""
$payloadFilePath     = ""

if (-not [string]::IsNullOrWhiteSpace($dashboardsDir)) {
    $templatesBaseDir   = Join-Path $dashboardsDir "templates"
    $templatesClientDir = Join-Path $templatesBaseDir "client"
    $templatesSharedDir = Join-Path $templatesBaseDir "shared"
    $outputDir          = Join-Path $dashboardsDir    "output"
    $payloadsDir        = Join-Path $dashboardsDir    "payloads"

    # Build the full path to the template the user selected
    if (-not [string]::IsNullOrWhiteSpace($dashboardFile)) {

        if ($dashboardFolder -eq "client") {
            $templateFilePath = Join-Path $templatesClientDir $dashboardFile
        }
        elseif ($dashboardFolder -eq "shared") {
            $templateFilePath = Join-Path $templatesSharedDir $dashboardFile
        }

        # Output file (only used for client uploads - shared uploads
        # send the template directly without a modified copy)
        if ($dashboardFolder -eq "client" -and -not [string]::IsNullOrWhiteSpace($clientName)) {
            $safeClientName  = ($clientName.ToLower().Trim() -replace '[^a-z0-9]+', '-').Trim('-')
            $outputFilePath  = Join-Path $outputDir   "$safeClientName-$dashboardFile"
            $payloadFilePath = Join-Path $payloadsDir "$safeClientName-$dashboardFile.payload.json"
        }
        elseif ($dashboardFolder -eq "shared") {
            $payloadFilePath = Join-Path $payloadsDir "shared-$dashboardFile.payload.json"
        }
    }
}


# ====================================================================
# Step 5 - Return the config hashtable
# ====================================================================
# PowerShell returns the last expression in a script. Callers get
# this hashtable via `$config = . .\config.ps1`.

@{
    # --- Grafana connection ---
    GrafanaUrl = $grafanaUrl
    Token      = $token

    # --- Dashboard selection ---
    DashboardFolder = $dashboardFolder   # "client" | "shared" | ""
    DashboardFile   = $dashboardFile     # raw filename
    DashboardTitle  = $dashboardTitle    # exact title in Grafana (delete only)

    # --- Folder deletion target ---
    # Only used by DeleteFolder. The folder's name as it appears in
    # Grafana - no parent path, just the name. The script looks it
    # up and disambiguates if multiple folders share this name.
    FolderName = $folderName

    # --- Client identity ---
    ClientName     = $clientName
    SubscriptionId = $subscriptionId

    # --- Local filesystem ---
    DashboardsDir       = $dashboardsDir
    TemplatesClientDir  = $templatesClientDir
    TemplatesSharedDir  = $templatesSharedDir
    OutputDir           = $outputDir
    PayloadsDir         = $payloadsDir
    TemplateFilePath    = $templateFilePath
    OutputFilePath      = $outputFilePath
    PayloadFilePath     = $payloadFilePath

    # --- Grafana folder names (fixed by spec) ---
    # Client: Client-Homepages / {ClientName}
    # Shared: Shared / Client-Dashboards
    ClientParentFolder = "Client-Homepages"
    SharedParentFolder = "Shared"
    SharedChildFolder  = "Client-Dashboards"

    # --- Template variable visibility ---
    # 0 = visible dropdown, 1 = label only, 2 = fully hidden
    HideSubVariable = 2
}
