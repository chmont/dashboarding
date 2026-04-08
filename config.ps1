$clientName = $env:Client_Name

if ([string]::IsNullOrWhiteSpace($clientName)) {
    throw "Client_Name environment variable is missing."
}

$safeName = $clientName.ToLower().Trim() -replace '[^a-z0-9]+', '-'
$safeName = $safeName.Trim('-')

@{
    GrafanaUrl      = $env:Grafana_Url
    Token           = $env:Token
    Namespace       = if ($env:Namespace) { $env:Namespace } else { "default" }

    ClientName      = $clientName
    SubscriptionId  = $env:Subscription

    FolderTitle     = $clientName
    FolderUid       = ""

    SourceDashboard = "..\dashboards\Client-Overview.json"
    OutputDashboard = "..\dashboards\client-overview.updated.json"

    DashboardTitle  = "$clientName Overview"
    DashboardName   = "$safeName-overview"

    HideSubVariable = 2
}