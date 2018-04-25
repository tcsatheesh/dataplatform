param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function Get-KeyVaultName {
    param (
        [string]$keyVaultType
    )
    $commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
    $parameterFileName = "keyvaults.parameters.json"
    $parameters = & "$commonPSFolder\Get-ResourceParameters.ps1" -projectsParameterFile $projectsParameterFile -parameterFileName $parameterFileName
    $resource = $parameters.parameters.resources.value | Where-Object {$_.type -eq $keyVaultType}
    $keyVaultName = $resource.name
    return $keyVaultName
}

function Remove-Resource {
    param (
        [string]$keyVaultName,
        [string]$name
    )

    $key = Get-AzureKeyVaultKey -VaultName $keyVaultName -Name $name -ErrorAction SilentlyContinue
    if ( $key -eq $null) {
        Write-Verbose "key $name not present in the key vault $keyVaultName"
    }
    else {
        Write-Verbose "Removing the key $name from the key vault $keyVaultName"
        $kyvlt = Remove-AzureKeyVaultKey -VaultName $keyVaultName -Name $name -Force -Confirm:$false
        Write-Verbose "key $secretName removed from the key vault $keyVaultName"
    }
}

function Remove-AllKeys {
    foreach ($resource in $parameters.parameters.resources.value) {
        $keyVaultName = Get-KeyVaultName -keyVaultType $resource.keyVaultType
        Write-Verbose "Removing resource $($resource.name) from $keyVaultName"
        Remove-Resource -keyVaultName $keyVaultName -name $resource.name
    }
}

$parameterFileName = "keyvaultkeys.parameters.json"
$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
$null = & "$commonPSFolder\Invoke-RemoveProcess.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -parameterFileName $parameterFileName `
    -procToRun {Remove-AllKeys}