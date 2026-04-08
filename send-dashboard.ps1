param(
    [Parameter(Mandatory = $true)]
    [hashtable]$Config
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $Config.OutputDashboard)) {
    throw "Updated dashboard file not found: $($Config.OutputDashboard)"
}

$headers = @{
    Authorization  = "Bearer $($Config.Token)"
    Accept         = "application/json"
    "Content-Type" = "application/json"
}

$dashboardSearchUri = "$($Config.GrafanaUrl)/api/search?query=$([uri]::EscapeDataString($Config.DashboardTitle))"
$searchResults = Invoke-RestMethod -Method Get -Uri $dashboardSearchUri -Headers $headers

$existingDashboard = $searchResults | Where-Object {
    $_.title -eq $Config.DashboardTitle -and $_.type -eq "dash-db"
}

if ($null -ne $existingDashboard) {
    Write-Host "Dashboard already exists: $($Config.DashboardTitle)"
    exit 0
}

$dashboard = Get-Content -Raw -Path $Config.OutputDashboard | ConvertFrom-Json

# Remove export-only fields if present
if ($dashboard.PSObject.Properties.Name -contains '__inputs') {
    $dashboard.PSObject.Properties.Remove('__inputs')
}
if ($dashboard.PSObject.Properties.Name -contains '__elements') {
    $dashboard.PSObject.Properties.Remove('__elements')
}
if ($dashboard.PSObject.Properties.Name -contains '__requires') {
    $dashboard.PSObject.Properties.Remove('__requires')
}

# Normalize create fields
$dashboard.id = $null
$dashboard.uid = $null
$dashboard.version = 0
$dashboard.title = $Config.DashboardTitle

# Fix library panel refs if needed
foreach ($panel in $dashboard.panels) {
    if ($panel.PSObject.Properties.Name -contains 'libraryPanel') {
        if (-not ($panel.PSObject.Properties.Name -contains 'type')) {
            $panel | Add-Member -NotePropertyName type -NotePropertyValue 'library-panel-ref'
        }
    }
}

$bodyObject = @{
    dashboard = $dashboard
    message   = "Automated dashboard deployment"
    overwrite = $false
}

if (-not [string]::IsNullOrWhiteSpace($Config.FolderUid)) {
    $bodyObject.folderUid = $Config.FolderUid
}

$body = $bodyObject | ConvertTo-Json -Depth 100

$debugPath = Join-Path (Split-Path -Parent $Config.OutputDashboard) "dashboard-submit-body.json"
$body | Set-Content -Path $debugPath -Encoding UTF8
Write-Host "Wrote submit body to: $debugPath"

$createUri = "$($Config.GrafanaUrl)/api/dashboards/db"

try {
    $response = Invoke-RestMethod -Method Post -Uri $createUri -Headers $headers -Body $body
    Write-Host "Submitted dashboard: $($Config.DashboardTitle)"
    if ($response.url) {
        Write-Host "Dashboard URL: $($Config.GrafanaUrl)$($response.url)"
    }
}
catch {
    Write-Host "Dashboard submit failed."

    if ($null -ne $_.Exception.Response) {
        $responseStream = $_.Exception.Response.GetResponseStream()
        $reader = New-Object System.IO.StreamReader($responseStream)
        $responseBody = $reader.ReadToEnd()

        Write-Host "Status Code:" $_.Exception.Response.StatusCode
        Write-Host "Status Description:" $_.Exception.Response.StatusDescription
        Write-Host "Response Body:"
        Write-Host $responseBody
    }

    Write-Host "Request body saved at:"
    Write-Host "  $debugPath"

    throw
}