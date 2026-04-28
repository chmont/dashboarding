# delete-dashboard.ps1
# ====================
# Deletes one dashboard from Grafana.
#
# HOW IT FINDS THE DASHBOARD:
#   You pass just the dashboard's title via -DashboardTitle (or
#   Dashboard_Title in env.base.ps1). The script calls Grafana's
#   /api/search, which returns every dashboard matching that title
#   along with each one's folder info.
#
#   - 0 matches -> exit cleanly
#   - 1 match   -> show its folder path, confirm, delete
#   - 2+ matches -> list each with its folder path, ask user to
#                   pick the correct one, then confirm, then delete
#
# NO DASHBOARD_FOLDER NEEDED:
#   Earlier versions required -DashboardFolder (client|shared) to
#   know where to look. We removed that - Grafana already knows
#   which folder each dashboard lives in, so we just let it tell us.

param(
    [Parameter(Mandatory = $true)]
    [hashtable]$Config
)

$ErrorActionPreference = "Stop"


# ====================================================================
# Step 1 - Validate inputs
# ====================================================================
if ([string]::IsNullOrWhiteSpace($Config.DashboardTitle)) {
    throw "Dashboard_Title is missing. Set it in env.base.ps1 or pass -DashboardTitle."
}

$searchTitle = $Config.DashboardTitle


# ====================================================================
# HTTP headers
# ====================================================================
$headers = @{
    Authorization = "Bearer $($Config.Token)"
    Accept        = "application/json"
}


# ====================================================================
# Step 2 - Search Grafana for dashboards matching the title
# ====================================================================
# /api/search is fuzzy, so we filter for exact title match after.

Write-Host "Looking up dashboards titled '$searchTitle'..."

$encodedTitle = [uri]::EscapeDataString($searchTitle)
$searchUri    = "$($Config.GrafanaUrl)/api/search?type=dash-db&query=$encodedTitle"
$searchResults = Invoke-RestMethod -Method Get -Uri $searchUri -Headers $headers

# Exact (case-sensitive) title match only
$matches = $searchResults | Where-Object { $_.title -eq $searchTitle }
$matches = @($matches)

if ($matches.Count -eq 0) {
    Write-Host "No dashboard titled '$searchTitle' found in Grafana. Nothing to delete."
    return
}

Write-Host "  Found $($matches.Count) dashboard(s) with that title."


# ====================================================================
# Step 3 - Resolve each match's folder path for display
# ====================================================================
# /api/search gives us folderUid and folderTitle (the direct parent),
# but not the grandparent. For typical display we just want
# "Parent / Title", which folderTitle already covers.
#
# When folderUid is empty, the dashboard lives in Grafana's root
# (the "General" folder), which we surface as "(top level)".

$matchInfo = @()
foreach ($match in $matches) {
    if ([string]::IsNullOrWhiteSpace($match.folderTitle)) {
        $folderLabel = "(top level)"
    } else {
        $folderLabel = $match.folderTitle
    }

    $matchInfo += [pscustomobject]@{
        Uid         = $match.uid
        Title       = $match.title
        FolderUid   = $match.folderUid
        FolderLabel = $folderLabel
        DisplayPath = "$folderLabel / $($match.title)"
    }
}


# ====================================================================
# Step 4 - If multiple matches, make the user pick
# ====================================================================
# Numbered list, simple integer prompt, loops on invalid input.

$selected = $null

if ($matchInfo.Count -eq 1) {
    $selected = $matchInfo[0]
} else {
    Write-Host ""
    Write-Host "Multiple dashboards match the title '$searchTitle':"
    for ($i = 0; $i -lt $matchInfo.Count; $i++) {
        $displayNum = $i + 1
        Write-Host "  [$displayNum] $($matchInfo[$i].DisplayPath)   (uid: $($matchInfo[$i].Uid))"
    }
    Write-Host ""

    do {
        $answer = (Read-Host "Which dashboard do you want to delete? (1-$($matchInfo.Count), or 'q' to quit)").Trim()

        if ($answer -match '^(?i)q$') {
            Write-Host "Cancelled. Nothing was deleted."
            return
        }

        $parsedNumber = 0
        $validNumber  = [int]::TryParse($answer, [ref]$parsedNumber)

        if ($validNumber -and $parsedNumber -ge 1 -and $parsedNumber -le $matchInfo.Count) {
            $selected   = $matchInfo[$parsedNumber - 1]
            $validInput = $true
        } else {
            Write-Host "  Please enter a number between 1 and $($matchInfo.Count), or 'q' to quit."
            $validInput = $false
        }
    } until ($validInput)
}


# ====================================================================
# Step 5 - Verify it still exists
# ====================================================================
# A quick GET on the dashboard's UID catches the rare case where it
# was deleted between our search and this prompt.

$dashboardUri = "$($Config.GrafanaUrl)/api/dashboards/uid/$($selected.Uid)"

Write-Host ""
Write-Host "Verifying dashboard in Grafana..."

try {
    $dashboardDetails = Invoke-RestMethod -Method Get -Uri $dashboardUri -Headers $headers
    $currentTitle = $dashboardDetails.dashboard.title
}
catch {
    Write-Host "Dashboard (uid: $($selected.Uid)) no longer exists. Nothing to delete."
    return
}


# ====================================================================
# Step 6 - Show the preview
# ====================================================================
Write-Host ""
Write-Host "About to delete:"
Write-Host "  Title:    $currentTitle"
Write-Host "  Location: $($selected.DisplayPath)"
Write-Host "  UID:      $($selected.Uid)"
Write-Host ""


# ====================================================================
# Step 7 - Confirmation loop
# ====================================================================
$confirmed = $false
do {
    $answer = (Read-Host "Are you sure you want to delete this dashboard? (y/n)").Trim()

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


# ====================================================================
# Step 8 - Act on the answer
# ====================================================================
if (-not $confirmed) {
    Write-Host "Cancelled. Dashboard was not deleted."
    return
}

Write-Host ""
Write-Host "Deleting '$currentTitle'..."

Invoke-RestMethod -Method Delete -Uri $dashboardUri -Headers $headers | Out-Null

Write-Host "  Deleted successfully."
