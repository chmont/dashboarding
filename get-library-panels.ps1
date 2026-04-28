$grafanaUrl = $env:Grafana_Url
$token = $env:Token


$headers = @{
    "Authorization" = "Bearer $token"
    "Content-Type"  = "application/json"
}
#api/library-elements/name/<Name-Of-Panel>"

$uri = "$grafanaUrl/api/library-elements/name/Link-panel/"

Write-Output $uri
 Invoke-RestMethod -Uri $uri -Headers $headers -Method Get
#Write-Output $response.result.uid
