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
        [string]$secretName
    )

    $secret = Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name $secretName -ErrorAction SilentlyContinue
    if ( $secret -eq $null) {
        Write-Verbose "Secret $secretName not present in the key vault $keyVaultName"
    }
    else {
        Write-Verbose "Removing the secret $secretName from the key vault $keyVaultName"
        $kyvlt = Remove-AzureKeyVaultSecret -VaultName $keyVaultName -Name $secretName -Force -Confirm:$false
        Write-Verbose "Secret $secretName removed from the key vault $keyVaultName"
    }
}

function Remove-AllSecrets {
    foreach ($resource in $parameters.parameters.resources.value) {
        $keyVaultName = Get-KeyVaultName -keyVaultType $resource.keyVaultType
        Write-Verbose "Removing resource $($resource.secretName) from $keyVaultName"
        Remove-Resource -keyVaultName $keyVaultName -secretName $resource.secretName
    }
}

$parameterFileName = "keyvaultsecrets.parameters.json"
$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
$null = & "$commonPSFolder\Invoke-RemoveProcess.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -parameterFileName $parameterFileName `
    -procToRun {Remove-AllSecrets}