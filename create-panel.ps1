$baseUrl = $env:Grafana_Url
$token   = $env:Token

$headers = @{
    Authorization = "Bearer $token"
    "Content-Type" = "application/json"
}

# This should be the UID of the child folder, not the title
$childFolderUid = "TestShared-Child"

# If you already have the panel JSON in a file:
$panelModel = Get-Content ".\dashboards\templates\panel\dashboard-pannel.json" -Raw | ConvertFrom-Json

$bodyObject = @{
    uid       = "custom-library-panel-uid"
    folderUid = $childFolderUid
    name      = "Dashboard Portal"
    kind      = 1
    model     = $panelModel
}

$body = $bodyObject | ConvertTo-Json -Depth 100

$response = Invoke-RestMethod `
    -Method Post `
    -Uri "$baseUrl/api/library-elements" `
    -Headers $headers `
    -Body $body

$response