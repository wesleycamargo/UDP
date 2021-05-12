
[CmdletBinding()]
param (
    [Parameter()]
    [string]$databricksWorkspaceName,
    [string]$databricksWorkspaceResourceGroup,
    
    # [string]$tenant,
    [string]$spnClientId,
    [string]$spnClientSecret,

    [string]$keyVaultName,
    [string]$keyVaultPATSecretName
)


function Get-SubscriptionInformation {
    return az account show | ConvertFrom-Json
}

function Get-DatabricksWorkspace {
    param (
        $databricksWorkspaceName,
        $databricksWorkspaceResourceGroup
    )
    
    az extension add -n databricks -y
    return az databricks workspace show -n $databricksWorkspaceName -g $databricksWorkspaceResourceGroup -o json | ConvertFrom-Json
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


function Get-DatabricksPAT {
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

function Register-DatabricksPATIntoKeyVault {
    param (
        $pat,
        $keyVaultName,
        $secretName
    )
    $return = az keyvault secret set --name $secretName --vault-name $keyVaultName --value $pat.token_value | ConvertFrom-Json
    Write-Host $return
    
    if($return.value){
        return "PAT successfully registered into Key Vault"
    }
}

function Register-AppConfiguration {
    param (
        $appconfigName,
        $label = "dev",
        $keyVaultPATSecretName
    )

    $databricksWorkspace = Get-DatabricksWorkspace -databricksWorkspaceName $databricksWorkspaceName -databricksWorkspaceResourceGroup $databricksWorkspaceResourceGroup 

    $databricksWorkspaceURL = "https://$($databricksWorkspace.workspaceUrl)"
    $databricksResourceId = $databricksWorkspace.id

    
    $return = az appconfig kv set -n $appconfigName --key databricksWorkspaceURL --label dev --value $databricksWorkspaceURL -y | ConvertFrom-Json
    if($return.value){
        Write-Host "databricksWorkspaceURL successfully registered into AppConfiguration"
    }
    
    $return = az appconfig kv set -n $appconfigName --key databricksResourceId --label dev --value $databricksResourceId -y | ConvertFrom-Json
    if($return.value){
        Write-Host "databricksResourceId successfully registered into AppConfiguration"
    }
    
    az appconfig kv set-keyvault -n $appconfigName --key $keyVaultPATSecretName --label $label --secret-identifier "https://keyvault5zpayvr2rt6ki.vault.azure.net/secrets/databricksAccessToken/7e85d961c0a949de8a16244a51ba9bba"
}



$pat = Get-DatabricksPAT -spnClientId $spnClientId -spnClientSecret $spnClientSecret -databricksWorkspaceName $databricksWorkspaceName -databricksWorkspaceResourceGroup $databricksWorkspaceResourceGroup #-tenant $tenant 

Register-DatabricksPATIntoKeyVault -pat $pat -keyVaultName $keyVaultName -secretName $keyVaultPATSecretName

Register-AppConfiguration -appconfigName appconfig5zpayvr2rt6ki -keyVaultPATSecretName $keyVaultPATSecretName