$ErrorActionPreference = "Stop"

Set-Location $PSScriptRoot

.\env.base.ps1
$config =  .\config.ps1

if ([string]::IsNullOrWhiteSpace($config.GrafanaUrl)) {
    throw "GrafanaUrl is missing."
}

if ([string]::IsNullOrWhiteSpace($config.Token)) {
    throw "Token is missing."
}

if ([string]::IsNullOrWhiteSpace($config.ClientName)) {
    throw "ClientName is missing."
}

if ([string]::IsNullOrWhiteSpace($config.SubscriptionId)) {
    throw "SubscriptionId is missing."
}

.\create-folder.ps1 -Config $config
.\update-dashboard.ps1 -Config $config
.\send-dashboard.ps1 -Config $config

Write-Host "Run completed successfully."