param(
  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$test
)

Describe 'Register Information' {
        
   Write-Host "Variable: $test "

        
    It 'Test variable' {
        
        $true | Should -Be $true
        
    }  
}