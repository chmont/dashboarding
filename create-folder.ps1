param(
    [Parameter(Mandatory = $true)]
    [hashtable]$Config
)

$ErrorActionPreference = "Stop"

$headers = @{
    Authorization = "Bearer $($Config.Token)"
    Accept        = "application/json"
}

$folderUid = $Config.FolderUid
$folderTitle = $Config.FolderTitle

$checkUri = "$($Config.GrafanaUrl)/apis/folder.grafana.app/v1beta1/namespaces/$($Config.Namespace)/folders/$folderUid"
$createUri = "$($Config.GrafanaUrl)/apis/folder.grafana.app/v1beta1/namespaces/$($Config.Namespace)/folders"

try {
    Invoke-RestMethod -Method Get -Uri $checkUri -Headers $headers | Out-Null
    Write-Host "Folder already exists: $folderTitle"
    exit 0
}
catch {
    $statusCode = $_.Exception.Response.StatusCode.value__
    if ($statusCode -ne 404) {
        throw
    }
}

$createHeaders = @{
    Authorization = "Bearer $($Config.Token)"
    Accept        = "application/json"
    "Content-Type" = "application/json"
}

$body = @{
    metadata = @{
        name = $folderUid
    }
    spec = @{
        title = $folderTitle
    }
} | ConvertTo-Json -Depth 10

Invoke-RestMethod -Method Post -Uri $createUri -Headers $createHeaders -Body $body | Out-Null
Write-Host "Created folder: $folderTitle"