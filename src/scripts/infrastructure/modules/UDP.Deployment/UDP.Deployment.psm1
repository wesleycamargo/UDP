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

function Get-ActiveDirectoryToken {
    param (
        $tenant,
        $spnClientId,
        $spnClientSecret,
        $resourceId
    )

    $body = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $body.Add("grant_type", "client_credentials")
    $body.Add("client_id", "$spnClientId")
    $body.Add("resource", "$resourceId")
    $body.Add("client_secret", "$spnClientSecret")

    $response = Invoke-RestMethod "https://login.microsoftonline.com/$tenant/oauth2/token" -Method "POST" -Body $body -ContentType "application/x-www-form-urlencoded"

    return $response.access_token
}

function Get-DatabricksHeaderFromSPN {
    param (
        [string]$spnClientId,
        [string]$spnClientSecret,
        [string]$databricksWorkspaceName,
        [string]$databricksWorkspaceResourceGroup
    )

    $subscriptionInfo = Get-SubscriptionInformation

    $databricksWorkspace = Get-DatabricksWorkspace -databricksWorkspaceName $databricksWorkspaceName -databricksWorkspaceResourceGroup $databricksWorkspaceResourceGroup 
    $databricksResourceId = $databricksWorkspace.id

    #constant for databricks, it doesn't change
    $databricksAdResource = "2ff814a6-3304-4ab8-85cb-cd0e6f879c1d"
    $databricksAdToken = Get-ActiveDirectoryToken -tenant $subscriptionInfo.tenantId -spnClientId $spnClientId -spnClientSecret $spnClientSecret -resourceId $databricksAdResource
    
    $managementEnpointResource = "https://management.core.windows.net/"
    $managementEndpointAdToken = Get-ActiveDirectoryToken -tenant $subscriptionInfo.tenantId -spnClientId $spnClientId -spnClientSecret $spnClientSecret -resourceId $managementEnpointResource

    $header = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $header.Add("Authorization", "Bearer $databricksAdToken")
    $header.Add("X-Databricks-Azure-SP-Management-Token", "$managementEndpointAdToken")
    $header.Add("X-Databricks-Azure-Workspace-Resource-Id", "$databricksResourceId")

    return $header
}

function Get-DatabricksClusters {
    param (
        [string]$tenant,
        [string]$spnClientId,
        [string]$spnClientSecret,
        [string]$databricksWorkspaceName,
        [string]$databricksWorkspaceResourceGroup
    )

    $header = Get-DatabricksHeaderFromSPN -spnClientId $spnClientId `
        -spnClientSecret $spnClientSecret `
        -databricksWorkspaceName $databricksWorkspaceName `
        -databricksWorkspaceResourceGroup $databricksWorkspaceResourceGroup

    $databricksWorkspace = Get-DatabricksWorkspace -databricksWorkspaceName $databricksWorkspaceName -databricksWorkspaceResourceGroup $databricksWorkspaceResourceGroup 
    $databricksWorkspaceURL = "https://$($databricksWorkspace.workspaceUrl)"

    $existingClusters = Invoke-RestMethod "$databricksWorkspaceURL/api/2.0/clusters/list" -Method "GET" -Headers $header

    return $existingClusters
}

function New-DatabricksPAT {
    param (
        [string]$spnClientId,
        [string]$spnClientSecret,
        [string]$databricksWorkspaceName,
        [string]$databricksWorkspaceResourceGroup
    )

    $header = Get-DatabricksHeaderFromSPN -spnClientId $spnClientId `
        -spnClientSecret $spnClientSecret `
        -databricksWorkspaceName $databricksWorkspaceName `
        -databricksWorkspaceResourceGroup $databricksWorkspaceResourceGroup

    $databricksWorkspace = Get-DatabricksWorkspace -databricksWorkspaceName $databricksWorkspaceName -databricksWorkspaceResourceGroup $databricksWorkspaceResourceGroup 
    $databricksWorkspaceURL = "https://$($databricksWorkspace.workspaceUrl)"

    $pat = Invoke-RestMethod "$databricksWorkspaceURL/api/2.0/token/create" -Method "POST" -Headers $header

    return $pat
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

    $header = Get-DatabricksHeaderFromSPN -spnClientId $spnClientId `
        -spnClientSecret $spnClientSecret `
        -databricksWorkspaceName $databricksWorkspaceName `
        -databricksWorkspaceResourceGroup $databricksWorkspaceResourceGroup

    $databricksWorkspace = Get-DatabricksWorkspace -databricksWorkspaceName $databricksWorkspaceName -databricksWorkspaceResourceGroup $databricksWorkspaceResourceGroup 
    $databricksWorkspaceURL = "https://$($databricksWorkspace.workspaceUrl)"

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




function New-DatabricksKeyVaultBackedScope {
    param (
        [string]$spnClientId,
        [string]$spnClientSecret,
        [string]$databricksWorkspaceName,
        [string]$databricksWorkspaceResourceGroup,
        [string]$keyVaultName
    )        

    
    $header = Get-DatabricksHeaderFromSPN -spnClientId $spnClientId `
        -spnClientSecret $spnClientSecret `
        -databricksWorkspaceName $databricksWorkspaceName `
        -databricksWorkspaceResourceGroup $databricksWorkspaceResourceGroup

    $databricksWorkspace = Get-DatabricksWorkspace -databricksWorkspaceName $databricksWorkspaceName -databricksWorkspaceResourceGroup $databricksWorkspaceResourceGroup 
    $databricksWorkspaceURL = "https://$($databricksWorkspace.workspaceUrl)"   


    $body = @{
        scope                  = 'my-simple-azure-keyvault-scope'
        scope_backend_type     = 'AZURE_KEYVAULT'        
 
        backend_azure_keyvault = @{
            resource_id = '/subscriptions/f8354c08-de3d-4a67-95ae-c7cbdb37fbf6/resourceGroups/WeS06DvDasc14726/providers/Microsoft.KeyVault/vaults/ah-poc-keyvault'
            dns_name    = 'https://ah-poc-keyvault.vault.azure.net/'            
        }
    } | ConvertTo-Json



      

    Invoke-RestMethod "$databricksWorkspaceURL/api/2.0/secrets/scopes/create" -Method 'POST' -Headers $header -Body $body -ContentType "application/json"

}

# $pat = New-DatabricksPAT -spnClientId $spnClientId -spnClientSecret $spnClientSecret -databricksWorkspaceName $databricksWorkspaceName -databricksWorkspaceResourceGroup $databricksWorkspaceResourceGroup #-tenant $tenant 

# Register-DatabricksPATIntoKeyVault -pat $pat -keyVaultName $keyVaultName -secretName $keyVaultPATSecretName

# Register-AppConfiguration -appconfigName appconfig5zpayvr2rt6ki -keyVaultPATSecretName $keyVaultPATSecretNameaz appconfig kv set-keyvault -n $appconfigName --key $keyVaultPATSecretName --label $label --secret-identifier $keyVaultPATSecretValue -y | ConvertFrom-Json