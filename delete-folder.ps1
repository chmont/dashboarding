# delete-folder.ps1
# =================
# Deletes a folder in Grafana along with every dashboard inside it.
#
# HOW IT FINDS THE FOLDER:
#   You pass just the folder's name via -FolderName (or Folder_Name
#   in env.base.ps1). The script calls Grafana's /api/search, which
#   returns every folder matching that name along with each one's
#   parent info.
#
#   - 0 matches -> exit cleanly
#   - 1 match   -> show its parent path, confirm, delete
#   - 2+ matches -> list each with its parent path, ask user to
#                   pick the correct one, then confirm, then delete
#
# THIS IS WHY YOU DON'T NEED A "PATH":
#   Grafana already tracks the parent relationship. Manually typing
#   a path just duplicates what Grafana knows. We let Grafana tell
#   us where each folder lives.
#
# STEPS:
#   1. Look up all folders with the given name.
#   2. For each match, resolve its parent's title so we can show
#      "Parent / Child" in the preview.
#   3. If multiple matches, prompt user to pick one (by number).
#   4. List dashboards inside the chosen folder.
#   5. Show preview + final confirmation prompt.
#   6. On y: delete each child dashboard, then the folder itself.
#      On n: cancel.

param(
    [Parameter(Mandatory = $true)]
    [hashtable]$Config
)

$ErrorActionPreference = "Stop"


# ====================================================================
# Step 1 - Validate inputs
# ====================================================================
if ([string]::IsNullOrWhiteSpace($Config.FolderName)) {
    throw "Folder_Name is missing. Set it in env.base.ps1 or pass -FolderName (e.g. 'Acme Corp')."
}

$searchName = $Config.FolderName


# ====================================================================
# HTTP headers
# ====================================================================
$headers = @{
    Authorization = "Bearer $($Config.Token)"
    Accept        = "application/json"
}


# ====================================================================
# Step 2 - Search Grafana for folders matching the name
# ====================================================================
# /api/search is fuzzy, so we filter for an exact title match after.

Write-Host "Looking up folders named '$searchName'..."

$encodedName = [uri]::EscapeDataString($searchName)
$searchUri   = "$($Config.GrafanaUrl)/api/search?type=dash-folder&query=$encodedName"
$searchResults = Invoke-RestMethod -Method Get -Uri $searchUri -Headers $headers

# Exact (case-sensitive) title match only
$matches = $searchResults | Where-Object { $_.title -eq $searchName }
$matches = @($matches)

if ($matches.Count -eq 0) {
    Write-Host "No folder named '$searchName' found in Grafana. Nothing to delete."
    return
}

Write-Host "  Found $($matches.Count) folder(s) with that name."


# ====================================================================
# Step 3 - Resolve each match's parent path
# ====================================================================
# /api/search gives us folderUid (the parent's UID) but NOT the
# parent's title. To display "Parent / Child", we call
# /api/folders/{uid} for each match, which includes parentUid and
# lets us look up the parent's title in a second request.
#
# We cache resolved parent titles so if multiple matches share the
# same parent, we don't re-query Grafana for the same info.

$parentTitleCache = @{}

function Get-ParentTitle {
    param([string]$ParentUid)

    if ([string]::IsNullOrWhiteSpace($ParentUid)) {
        return "(top level)"
    }
    if ($parentTitleCache.ContainsKey($ParentUid)) {
        return $parentTitleCache[$ParentUid]
    }

    try {
        $parentDetails = Invoke-RestMethod `
            -Method Get `
            -Uri "$($Config.GrafanaUrl)/api/folders/$ParentUid" `
            -Headers $headers
        $title = $parentDetails.title
    }
    catch {
        $title = "(unknown parent)"
    }

    $parentTitleCache[$ParentUid] = $title
    return $title
}

# Build display info for every match
$matchInfo = @()
foreach ($match in $matches) {
    # /api/folders/{uid} gives us the authoritative folder details
    # including parentUid. /api/search's "folderUid" can be inconsistent.
    $folderDetails = Invoke-RestMethod `
        -Method Get `
        -Uri "$($Config.GrafanaUrl)/api/folders/$($match.uid)" `
        -Headers $headers

    $parentTitle = Get-ParentTitle -ParentUid $folderDetails.parentUid

    $matchInfo += [pscustomobject]@{
        Uid         = $match.uid
        Title       = $match.title
        ParentUid   = $folderDetails.parentUid
        ParentTitle = $parentTitle
        DisplayPath = "$parentTitle / $($match.title)"
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
    Write-Host "Multiple folders match the name '$searchName':"
    for ($i = 0; $i -lt $matchInfo.Count; $i++) {
        $displayNum = $i + 1
        Write-Host "  [$displayNum] $($matchInfo[$i].DisplayPath)   (uid: $($matchInfo[$i].Uid))"
    }
    Write-Host ""

    # Prompt loop - must be a valid number in range
    do {
        $answer = (Read-Host "Which folder do you want to delete? (1-$($matchInfo.Count), or 'q' to quit)").Trim()

        if ($answer -match '^(?i)q$') {
            Write-Host "Cancelled. Nothing was deleted."
            return
        }

        $parsedNumber = 0
        $validNumber  = [int]::TryParse($answer, [ref]$parsedNumber)

        if ($validNumber -and $parsedNumber -ge 1 -and $parsedNumber -le $matchInfo.Count) {
            $selected  = $matchInfo[$parsedNumber - 1]
            $validInput = $true
        } else {
            Write-Host "  Please enter a number between 1 and $($matchInfo.Count), or 'q' to quit."
            $validInput = $false
        }
    } until ($validInput)
}


# ====================================================================
# Step 5 - List dashboards inside the selected folder
# ====================================================================
Write-Host ""
Write-Host "Listing dashboards inside '$($selected.DisplayPath)'..."

$childSearchUri  = "$($Config.GrafanaUrl)/api/search?type=dash-db&folderUIDs=$($selected.Uid)"
$childDashboards = Invoke-RestMethod -Method Get -Uri $childSearchUri -Headers $headers

# Force array shape - with 0 or 1 items, PowerShell may give us $null
# or a single object, which breaks .Count and foreach.
$childDashboards = @($childDashboards)
$childCount      = $childDashboards.Count


# ====================================================================
# Step 6 - Show the preview
# ====================================================================
Write-Host ""
Write-Host "About to delete:"
Write-Host "  Folder:     $($selected.Title)"
Write-Host "  Location:   $($selected.DisplayPath)"
Write-Host "  UID:        $($selected.Uid)"
Write-Host "  Dashboards: $childCount"

if ($childCount -gt 0) {
    foreach ($child in $childDashboards) {
        Write-Host "    - $($child.title)  (uid: $($child.uid))"
    }
}
Write-Host ""


# ====================================================================
# Step 7 - Final confirmation (y/n loop)
# ====================================================================
$confirmed = $false
do {
    $answer = (Read-Host "Are you sure you want to delete this folder and its dashboards? (y/n)").Trim()

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
    Write-Host "Cancelled. Folder was not deleted."
    return
}


# ====================================================================
# Step 8 - Delete every child dashboard first
# ====================================================================
# Explicit deletes give us per-item logging. If one fails, we stop
# and leave the folder intact for investigation.

if ($childCount -gt 0) {
    Write-Host ""
    Write-Host "Deleting $childCount dashboard(s)..."

    $index = 0
    foreach ($child in $childDashboards) {
        $index++
        $childUri = "$($Config.GrafanaUrl)/api/dashboards/uid/$($child.uid)"

        Write-Host "  [$index/$childCount] Deleting '$($child.title)' (uid: $($child.uid))..."

        try {
            Invoke-RestMethod -Method Delete -Uri $childUri -Headers $headers | Out-Null
            Write-Host "    OK"
        }
        catch {
            Write-Host "    FAILED: $($_.Exception.Message)"
            Write-Host "Stopping. Folder NOT deleted. Fix the error and rerun."
            throw
        }
    }
}


# ====================================================================
# Step 9 - Delete the folder itself
# ====================================================================
Write-Host ""
Write-Host "Deleting folder '$($selected.Title)'..."

$folderDeleteUri = "$($Config.GrafanaUrl)/api/folders/$($selected.Uid)"
Invoke-RestMethod -Method Delete -Uri $folderDeleteUri -Headers $headers | Out-Null

Write-Host "  Deleted successfully."
