param(

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$spnClientId,  

  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$spnClientSecret,

  $databricksWorkspaceName,
  $databricksWorkspaceResourceGroup,
  $keyVaultName,
  $keyVaultPATSecretName 

)

# Invoke-Pester -Script @{ Path =  '.\databricks.tests.ps1' } #; Parameters = @{spnClientId  = $spnClientId; spnClientSecret = $spnClientSecret} }
# Invoke-Pester -Script @{ Path =  '.\databricks.tests.ps1'; Parameters = @{spnClientId  = $spnClientId; spnClientSecret = $spnClientSecret} }
# Invoke-Pester ".\databricks.tests.ps1"

$container = New-PesterContainer -Path '.\databricks.tests.ps1' -Data @{ spnClientId = $spnClientId; `
                                                                         spnClientSecret =  $spnClientSecret; `
                                                                         databricksWorkspaceName = $databricksWorkspaceName; `
                                                                         databricksWorkspaceResourceGroup = $databricksWorkspaceResourceGroup; `
                                                                         keyVaultName = $keyVaultName; `
                                                                         keyVaultPATSecretName = $keyVaultPATSecretName   
                                                                        }
Invoke-Pester -Container $container

# Invoke-Pester -Script @{ Path =  'C:\lx\repo\wes\UDP\src\scripts\tests\databricks.tests.ps1' }