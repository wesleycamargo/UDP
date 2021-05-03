
[CmdletBinding()]
param (
    [Parameter()]
    [string]$clusterConfigurationFile,
    [string]$clusterName,
    [string]$databricksWorkspaceURL,
    [string]$databricksResourceId,
    
    [string]$tenant,
    [string]$spnClientId,
    [string]$spnClientSecret
)

#region #################### Tokens ####################


function Get-ActiveDirectoryToken {
    param (
        $tenant,
        $spnClientId,
        $spnClientSecret
    )

    $resourceId = "2ff814a6-3304-4ab8-85cb-cd0e6f879c1d"
    
    $body = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $body.Add("grant_type", "client_credentials")
    $body.Add("client_id", "$spnClientId")
    $body.Add("resource", "$resourceId")
    $body.Add("client_secret", "$spnClientSecret")

    $response = Invoke-RestMethod "https://login.microsoftonline.com/$tenant/oauth2/token" -Method "POST" -Body $body -ContentType "application/x-www-form-urlencoded"

    return $response.access_token

}

function Get-ManagementEndpointToken {
    param (
        $tenant,
        $spnClientId,
        $spnClientSecret
    )

    $header = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $header.Add("Content-Type", "application/x-www-form-urlencoded")

    $resourceId = "https://management.core.windows.net/"

    $body = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $body.Add("grant_type", "client_credentials")
    $body.Add("client_id", "$spnClientId")
    $body.Add("resource", "$resourceId")
    $body.Add("client_secret", "$spnClientSecret")

    $response = Invoke-RestMethod "https://login.microsoftonline.com/$tenant/oauth2/token"  -Method 'POST' -Body $body -Headers $header

    return $response.access_token

}

#endregion ############### Tokens ####################


function New-DatabricksCluster {
    param (
        [string]$databricksWorkspaceURL,
        [string]$databricksResourceId,
        [string]$clusterName,
        [string]$clusterConfigurationFile        
    )
    
    $adToken = Get-ActiveDirectoryToken
    $managementEndpointToken = Get-ManagementEndpointToken

    $header = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $header.Add("Authorization", "Bearer $adToken")
    $header.Add("X-Databricks-Azure-SP-Management-Token", "$managementEndpointToken")
    $header.Add("X-Databricks-Azure-Workspace-Resource-Id", "$databricksResourceId")

    $clusterConfig = (Get-Content $clusterConfigurationFile | ConvertFrom-Json) 
    $clusterConfig.cluster_name = $clusterName
    $clusterConfig.idempotency_token = $clusterName

    $existingClusters = Invoke-RestMethod "$databricksWorkspaceURL/api/2.0/clusters/list" -Method "GET" -Headers $header

    $clusters = $existingClusters.clusters | Where { $_.cluster_name -eq "$clusterName" }

    if ($clusters.count -eq 0) {
        $body = ($clusterConfig | ConvertTo-Json -Depth 10)

        Write-Host "Creating cluster '$clusterName'..."
        Write-Host $body
    
        $create = Invoke-RestMethod "$databricksWorkspaceURL/api/2.0/clusters/create" -Method 'POST' -Headers $header -body $body
        $create |  ConvertTo-Json -Depth 10    
    }else {
        foreach ($cluster in $clusters) {

            Write-Host "Cluster '$clusterName' already exists with id $($cluster.cluster_id)"
            Write-Warning "Updating, this process will restart the cluster..."

            $clusterConfig.cluster_id = $cluster.cluster_id
            $body = ($clusterConfig | ConvertTo-Json -Depth 10)

            Write-Host $body

            Invoke-RestMethod "$databricksWorkspaceURL/api/2.0/clusters/edit" -Method 'POST' -Headers $header -body $body
        }
    }
}

New-DatabricksCluster -databricksWorkspaceURL $databricksWorkspaceURL -databricksResourceId $databricksResourceId -clusterName $clusterName -clusterConfigurationFile $clusterConfigurationFile