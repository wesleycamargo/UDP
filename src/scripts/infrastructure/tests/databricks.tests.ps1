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
  $keyVaultName,

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  $keyVaultPATSecretName,
  $customModulesDirectory
)
    
Describe 'Register Information' {
        
    $module = "UDP.Deployment"

    $module = Join-Path -Path $customModulesDirectory -ChildPath "UDP.Deployment"

    Import-Module $module -Force

    az login --service-principal --username $spnClientId --password $spnClientSecret --tenant $tenant

    It 'Should return PAT' {
        
        $pat = Get-DatabricksPAT -spnClientId $spnClientId -spnClientSecret $spnClientSecret -databricksWorkspaceName $databricksWorkspaceName -databricksWorkspaceResourceGroup $databricksWorkspaceResourceGroup #-tenant $tenant 

        $pat | Should -Not -BeNullOrEmpty
        $pat.token_value | Should -Not -BeNullOrEmpty
        $pat.token_value | Should -BeLike "dapi*"
    }    
    
    It 'Should create key vault secret' {
        
        $pat = Get-DatabricksPAT -spnClientId $spnClientId -spnClientSecret $spnClientSecret -databricksWorkspaceName $databricksWorkspaceName -databricksWorkspaceResourceGroup $databricksWorkspaceResourceGroup #-tenant $tenant 

        $secret = Register-DatabricksPATIntoKeyVault -pat $pat -keyVaultName $keyVaultName -secretName $keyVaultPATSecretName

        $secret | Should -Not -BeNullOrEmpty        
    }

    It 'Should create app configuration variables' {
             
        $pat = Get-DatabricksPAT -spnClientId $spnClientId -spnClientSecret $spnClientSecret -databricksWorkspaceName $databricksWorkspaceName -databricksWorkspaceResourceGroup $databricksWorkspaceResourceGroup #-tenant $tenant 

        $secret = Register-DatabricksPATIntoKeyVault -pat $pat -keyVaultName $keyVaultName -secretName $keyVaultPATSecretName

        $regex = "([\w.\/:]+\/secrets\/[\w]+)\/"

        $secret -match $regex

        $secretId = $Matches[1]

        Register-AppConfiguration -appconfigName appconfig5zpayvr2rt6ki -keyVaultPATSecretName $keyVaultPATSecretName -keyVaultPATSecretValue $secretId -databricksWorkspaceName $databricksWorkspaceName -databricksWorkspaceResourceGroup $databricksWorkspaceResourceGroup

        $appConfigSecret = az appconfig kv show -n appconfig5zpayvr2rt6ki --key $keyVaultPATSecretName --label dev | ConvertFrom-Json

        ($appConfigSecret.value | ConvertFrom-Json).uri | Should -Not -BeNullOrEmpty


    }
}        
