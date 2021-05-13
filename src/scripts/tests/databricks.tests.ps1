
    
Describe 'Register Information' {
        
    $module = "C:\lx\repo\wes\UDP\src\scripts\infrastructure\modules\UDP.Deployment\UDP.Deployment.psm1"

    Import-Module $module -Force
        
    $databricksWorkspaceName = "databricks-udp"
    $databricksWorkspaceResourceGroup = "RG-ARMdatapipeline"        
        
    $spnClientId = "e831ed10-140d-419f-a4aa-4c48965372d7"
    $spnClientSecret = "KYVl.FxSf.IpPOqhU7.4LVRRj3x4hE2Mp~"
    
    $keyVaultName = "keyvault5zpayvr2rt6ki"
    $keyVaultPATSecretName = "databricksAccessToken"

    It 'Should return PAT' {
        
        $module = "C:\lx\repo\wes\UDP\src\scripts\infrastructure\modules\UDP.Deployment\UDP.Deployment.psm1"
        Import-Module $module -Force
        
        $databricksWorkspaceName = "databricks-udp"
        $databricksWorkspaceResourceGroup = "RG-ARMdatapipeline"        
            
        $spnClientId = "e831ed10-140d-419f-a4aa-4c48965372d7"
        $spnClientSecret = "KYVl.FxSf.IpPOqhU7.4LVRRj3x4hE2Mp~"
            
        $pat = Get-DatabricksPAT -spnClientId $spnClientId -spnClientSecret $spnClientSecret -databricksWorkspaceName $databricksWorkspaceName -databricksWorkspaceResourceGroup $databricksWorkspaceResourceGroup #-tenant $tenant 

        $pat | Should -Not -BeNullOrEmpty
        $pat.token_value | Should -Not -BeNullOrEmpty
        $pat.token_value | Should -BeLike "dapi*"
    }    
    
    It 'Should create key vault secret' {
        
        $module = "C:\lx\repo\wes\UDP\src\scripts\infrastructure\modules\UDP.Deployment\UDP.Deployment.psm1"
        Import-Module $module -Force

        $databricksWorkspaceName = "databricks-udp"
        $databricksWorkspaceResourceGroup = "RG-ARMdatapipeline"        
            
        $spnClientId = "e831ed10-140d-419f-a4aa-4c48965372d7"
        $spnClientSecret = "KYVl.FxSf.IpPOqhU7.4LVRRj3x4hE2Mp~"

        $keyVaultName = "keyvault5zpayvr2rt6ki"
        $keyVaultPATSecretName = "databricksAccessToken"
        
        $pat = Get-DatabricksPAT -spnClientId $spnClientId -spnClientSecret $spnClientSecret -databricksWorkspaceName $databricksWorkspaceName -databricksWorkspaceResourceGroup $databricksWorkspaceResourceGroup #-tenant $tenant 

        $secret = Register-DatabricksPATIntoKeyVault -pat $pat -keyVaultName $keyVaultName -secretName $keyVaultPATSecretName

        $secret | Should -Not -BeNullOrEmpty        
    }

    It 'Should create app configuration variables' {
        
        $module = "C:\lx\repo\wes\UDP\src\scripts\infrastructure\modules\UDP.Deployment\UDP.Deployment.psm1"
        Import-Module $module -Force

        $databricksWorkspaceName = "databricks-udp"
        $databricksWorkspaceResourceGroup = "RG-ARMdatapipeline"        
            
        $spnClientId = "e831ed10-140d-419f-a4aa-4c48965372d7"
        $spnClientSecret = "KYVl.FxSf.IpPOqhU7.4LVRRj3x4hE2Mp~"

        $keyVaultName = "keyvault5zpayvr2rt6ki"
        $keyVaultPATSecretName = "databricksAccessToken"
        
        $pat = Get-DatabricksPAT -spnClientId $spnClientId -spnClientSecret $spnClientSecret -databricksWorkspaceName $databricksWorkspaceName -databricksWorkspaceResourceGroup $databricksWorkspaceResourceGroup #-tenant $tenant 

        $secret = Register-DatabricksPATIntoKeyVault -pat $pat -keyVaultName $keyVaultName -secretName $keyVaultPATSecretName

        Register-AppConfiguration -appconfigName appconfig5zpayvr2rt6ki -keyVaultPATSecretName $keyVaultPATSecretName -keyVaultPATSecretValue $secret.id -databricksWorkspaceName $databricksWorkspaceName -databricksWorkspaceResourceGroup $databricksWorkspaceResourceGroup

        $appConfigSecret = az appconfig kv show -n appconfig5zpayvr2rt6ki --key $keyVaultPATSecretName --label dev | ConvertFrom-Json

        ($appConfigSecret.value | ConvertFrom-Json).uri | Should -Be  $secret.id

    }
}        
