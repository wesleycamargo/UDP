function Get-SubscriptionInformation {
    return az account show | ConvertFrom-Json
}

function Get-DatabricksWorkspace {
    param (
        $databricksWorkspaceName,
        $databricksWorkspaceResourceGroup
    )
    
    # az extension add -n databricks -y 
    az config set extension.use_dynamic_install=yes_without_prompt --only-show-errors
    return az databricks workspace show -n $databricksWorkspaceName -g $databricksWorkspaceResourceGroup -o json --only-show-errors | ConvertFrom-Json
}

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


function New-DatabricksPAT {
    param (
        [string]$clusterName,
        [string]$clusterConfigurationFile,
        # [string]$tenant,
        [string]$spnClientId,
        [string]$spnClientSecret,
        [string]$databricksWorkspaceName,
        [string]$databricksWorkspaceResourceGroup
    )

    $subscriptionInfo = Get-SubscriptionInformation

    $databricksWorkspace = Get-DatabricksWorkspace -databricksWorkspaceName $databricksWorkspaceName -databricksWorkspaceResourceGroup $databricksWorkspaceResourceGroup 

    $databricksWorkspaceURL = "https://$($databricksWorkspace.workspaceUrl)"
    $databricksResourceId = $databricksWorkspace.id

    $adToken = Get-ActiveDirectoryToken -tenant $subscriptionInfo.tenantId -spnClientId $spnClientId -spnClientSecret $spnClientSecret
    $managementEndpointToken = Get-ManagementEndpointToken -tenant $subscriptionInfo.tenantId -spnClientId $spnClientId -spnClientSecret $spnClientSecret

    $header = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $header.Add("Authorization", "Bearer $adToken")
    $header.Add("X-Databricks-Azure-SP-Management-Token", "$managementEndpointToken")
    $header.Add("X-Databricks-Azure-Workspace-Resource-Id", "$databricksResourceId")

    $pat = Invoke-RestMethod "$databricksWorkspaceURL/api/2.0/token/create" -Method "POST" -Headers $header

    return $pat
}

function Get-DatabricksClusters {
    param (
        [string]$clusterName,
        [string]$clusterConfigurationFile,
        [string]$tenant,
        [string]$spnClientId,
        [string]$spnClientSecret,
        [string]$databricksWorkspaceName,
        [string]$databricksWorkspaceResourceGroup
    )

    $databricksWorkspace = Get-DatabricksWorkspace -databricksWorkspaceName $databricksWorkspaceName -databricksWorkspaceResourceGroup $databricksWorkspaceResourceGroup 

    $databricksWorkspaceURL = "https://$($databricksWorkspace.workspaceUrl)"
    $databricksResourceId = $databricksWorkspace.id

    $adToken = Get-ActiveDirectoryToken -tenant $tenant -spnClientId $spnClientId -spnClientSecret $spnClientSecret
    $managementEndpointToken = Get-ManagementEndpointToken -tenant $tenant -spnClientId $spnClientId -spnClientSecret $spnClientSecret

    $header = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $header.Add("Authorization", "Bearer $adToken")
    $header.Add("X-Databricks-Azure-SP-Management-Token", "$managementEndpointToken")
    $header.Add("X-Databricks-Azure-Workspace-Resource-Id", "$databricksResourceId")

    $existingClusters = Invoke-RestMethod "$databricksWorkspaceURL/api/2.0/clusters/list" -Method "GET" -Headers $header

    return $existingClusters
}

function Register-DatabricksPATIntoKeyVault {
    param (
        $pat,
        $keyVaultName,
        $secretName
    )
    $return = az keyvault secret set --name $secretName --vault-name $keyVaultName --value $pat.token_value | ConvertFrom-Json
    Write-Host $return
    
    if ($return.value) {
        Write-Host "PAT successfully registered into Key Vault"
    }
    return $return
}

function Register-AppConfiguration {
    param (
        [string]$appconfigName,
        [string]$label = "dev",
        [string]$keyVaultPATSecretName,
        [string]$keyVaultPATSecretValue       
    )
    
    $return = az appconfig kv set-keyvault -n $appconfigName --key $keyVaultPATSecretName --label $label --secret-identifier $keyVaultPATSecretValue -y | ConvertFrom-Json
    
    if ($return.value) {
        Write-Host "$keyVaultPATSecretName successfully linked into AppConfiguration"
    }
}


function New-DatabricksCluster {
    param (
        [string]$clusterName,
        [string]$clusterConfigurationFile,
        [string]$tenant,
        [string]$spnClientId,
        [string]$spnClientSecret,
        [string]$databricksWorkspaceName,
        [string]$databricksWorkspaceResourceGroup,
        [string]$appconfigName
    )

    $databricksWorkspace = Get-DatabricksWorkspace -databricksWorkspaceName $databricksWorkspaceName -databricksWorkspaceResourceGroup $databricksWorkspaceResourceGroup 

    $databricksWorkspaceURL = "https://$($databricksWorkspace.workspaceUrl)"
    $databricksResourceId = $databricksWorkspace.id

    $adToken = Get-ActiveDirectoryToken -tenant $tenant -spnClientId $spnClientId -spnClientSecret $spnClientSecret
    $managementEndpointToken = Get-ManagementEndpointToken -tenant $tenant -spnClientId $spnClientId -spnClientSecret $spnClientSecret

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

        Write-Host "Cluster created with Id: $($create.cluster_id)"

        $keyName = $databricksWorkspaceName + $clusterName + "Id"

        # $clusters = Get-DatabricksClusters -clusterName $clusterName -clusterConfigurationFile $clusterConfigurationFile -tenant $tenant -spnClientId $spnClientId -spnClientSecret $spnClientSecret -databricksWorkspaceName $databricksWorkspaceName -databricksWorkspaceResourceGroup $databricksWorkspaceResourceGroup 
        # $clusters[0].cluster_id
    
        $return = az appconfig kv set -n $appconfigName --key $keyName --label dev --value $create.cluster_id -y | ConvertFrom-Json
        if ($return.value) {
            Write-Host "databricksClusterId successfully registered into AppConfiguration"
        }
        

        
    }
    else {
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
# $pat = New-DatabricksPAT -spnClientId $spnClientId -spnClientSecret $spnClientSecret -databricksWorkspaceName $databricksWorkspaceName -databricksWorkspaceResourceGroup $databricksWorkspaceResourceGroup #-tenant $tenant 

# Register-DatabricksPATIntoKeyVault -pat $pat -keyVaultName $keyVaultName -secretName $keyVaultPATSecretName

# Register-AppConfiguration -appconfigName appconfig5zpayvr2rt6ki -keyVaultPATSecretName $keyVaultPATSecretNameaz appconfig kv set-keyvault -n $appconfigName --key $keyVaultPATSecretName --label $label --secret-identifier $keyVaultPATSecretValue -y | ConvertFrom-Json