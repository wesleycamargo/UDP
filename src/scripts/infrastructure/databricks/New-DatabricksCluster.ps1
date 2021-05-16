
[CmdletBinding()]
param (
    [Parameter()]
    [string]$clusterConfigurationFile,
    [string]$clusterName,
    [string]$databricksWorkspaceName,
    [string]$databricksWorkspaceResourceGroup,
    
    [string]$tenant,
    [string]$spnClientId,
    [string]$spnClientSecret,
    [string]$customModulesDirectory
)

$module = "UDP.Deployment"
$module = Join-Path -Path $customModulesDirectory -ChildPath "UDP.Deployment"
Import-Module $module -Force

New-DatabricksCluster -clusterName $clusterName -clusterConfigurationFile $clusterConfigurationFile -tenant $tenant -spnClientId $spnClientId -spnClientSecret $spnClientSecret -databricksWorkspaceName $databricksWorkspaceName -databricksWorkspaceResourceGroup $databricksWorkspaceResourceGroup 