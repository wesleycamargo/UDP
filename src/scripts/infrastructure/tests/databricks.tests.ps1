param(
  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$spnClientId,  

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$spnClientSecret,

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
  $keyVaultPATSecretName 
)
    
Describe 'Register Information' {
        
    $module = "C:\lx\repo\wes\UDP\src\scripts\infrastructure\modules\UDP.Deployment\UDP.Deployment.psm1"

    Import-Module $module -Force
        
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

        Register-AppConfiguration -appconfigName appconfig5zpayvr2rt6ki -keyVaultPATSecretName $keyVaultPATSecretName -keyVaultPATSecretValue $secret.id -databricksWorkspaceName $databricksWorkspaceName -databricksWorkspaceResourceGroup $databricksWorkspaceResourceGroup

        $appConfigSecret = az appconfig kv show -n appconfig5zpayvr2rt6ki --key $keyVaultPATSecretName --label dev | ConvertFrom-Json

        ($appConfigSecret.value | ConvertFrom-Json).uri | Should -Be  $secret.id

    }
}        
