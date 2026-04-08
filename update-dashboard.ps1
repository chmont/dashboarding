param(
    [Parameter(Mandatory = $true)]
    [hashtable]$Config
)

$ErrorActionPreference = "Stop"

Write-Host "Loading dashboard from: $($Config.SourceDashboard)"

if (-not (Test-Path $Config.SourceDashboard)) {
    throw "Source dashboard not found: $($Config.SourceDashboard)"
}

$dashboard = Get-Content -Raw -Path $Config.SourceDashboard | ConvertFrom-Json

$dashboard.title = $Config.DashboardTitle
$dashboard.uid = ""

if (-not $dashboard.templating -or -not $dashboard.templating.list) {
    throw "Dashboard JSON does not contain templating.list"
}

$subVar = $dashboard.templating.list | Where-Object { $_.name -eq "sub" }

if ($null -eq $subVar) {
    throw "Could not find templating variable 'sub' in dashboard JSON."
}

Write-Host "Found templating variable: sub"
Write-Host "sub properties: $($subVar.PSObject.Properties.Name -join ', ')"

if (-not $subVar.current) {
    throw "Templating variable 'sub' does not contain a current property."
}

$subVar.current.text  = $Config.ClientName
$subVar.current.value = $Config.SubscriptionId

if ($subVar.PSObject.Properties.Name -contains 'hide') {
    $subVar.hide = $Config.HideSubVariable
}
else {
    $subVar | Add-Member -NotePropertyName hide -NotePropertyValue $Config.HideSubVariable
}

if ($subVar.PSObject.Properties.Name -contains 'query' -and $null -ne $subVar.query) {
    if ($subVar.query.PSObject.Properties.Name -contains 'subscription') {
        $subVar.query.subscription = $Config.SubscriptionId
    }

    if (
        $subVar.query.PSObject.Properties.Name -contains 'grafanaTemplateVariableFn' -and
        $null -ne $subVar.query.grafanaTemplateVariableFn -and
        $subVar.query.grafanaTemplateVariableFn.PSObject.Properties.Name -contains 'subscription'
    ) {
        $subVar.query.grafanaTemplateVariableFn.subscription = $Config.SubscriptionId
    }
}

$outputDir = Split-Path -Parent $Config.OutputDashboard
if (-not (Test-Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$dashboard | ConvertTo-Json -Depth 100 | Set-Content -Path $Config.OutputDashboard -Encoding UTF8

Write-Host "Updated dashboard title: $($Config.DashboardTitle)"
Write-Host "Updated subscription variable:"
Write-Host "  text  = $($subVar.current.text)"
Write-Host "  value = $($subVar.current.value)"
Write-Host "  hide  = $($subVar.hide)"

if ($subVar.query -and $subVar.query.PSObject.Properties.Name -contains 'subscription') {
    Write-Host "  query.subscription = $($subVar.query.subscription)"
}

if (
    $subVar.query -and
    $subVar.query.PSObject.Properties.Name -contains 'grafanaTemplateVariableFn' -and
    $subVar.query.grafanaTemplateVariableFn -and
    $subVar.query.grafanaTemplateVariableFn.PSObject.Properties.Name -contains 'subscription'
) {
    Write-Host "  query.grafanaTemplateVariableFn.subscription = $($subVar.query.grafanaTemplateVariableFn.subscription)"
}

Write-Host "Wrote updated dashboard to: $($Config.OutputDashboard)"