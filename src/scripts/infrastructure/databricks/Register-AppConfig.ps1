
# [CmdletBinding()]
# param (
#     [Parameter()]
#     [string]$databricksWorkspaceName,
#     [string]$databricksWorkspaceResourceGroup,
    
#     # [string]$tenant,
#     [string]$spnClientId,
#     [string]$spnClientSecret,

#     [string]$keyVaultName,
#     [string]$keyVaultPATSecretName
# )

param(
  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$spnClientId,
  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$spnClientSecret,
  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$tenant,

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  $databricksWorkspaceName,

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  $databricksWorkspaceResourceGroup,

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  $appConfigName,
  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  $keyVaultName,
  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  $keyVaultPATSecretName,
  $customModulesDirectory,
  $clusterName
)

$module = "UDP.Deployment"

$module = Join-Path -Path $customModulesDirectory -ChildPath "UDP.Deployment"

Import-Module $module -Force


$pat = Get-DatabricksPAT -spnClientId $spnClientId -spnClientSecret $spnClientSecret -databricksWorkspaceName $databricksWorkspaceName -databricksWorkspaceResourceGroup $databricksWorkspaceResourceGroup #-tenant $tenant 

$secret = Register-DatabricksPATIntoKeyVault -pat $pat -keyVaultName $keyVaultName -secretName $keyVaultPATSecretName

$regex = "([\w.\/:]+\/secrets\/[\w]+)\/"

$secret -match $regex

$secretId = $Matches[1]

Register-AppConfiguration -appconfigName $appConfigName -keyVaultPATSecretName $keyVaultPATSecretName -keyVaultPATSecretValue $secretId -databricksWorkspaceName $databricksWorkspaceName -databricksWorkspaceResourceGroup $databricksWorkspaceResourceGroup -clusterName $clusterName
