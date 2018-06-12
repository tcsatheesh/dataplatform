param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function Remove-Secret {
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

function Remove-Resource {
    param (
        [object]$resource
    )
        $keyVaultName = Get-KeyVaultName -keyVaultType $resource.keyVaultType
        Write-Verbose "Removing resource $($resource.secretName) from $keyVaultName"
        Remove-Secret -keyVaultName $keyVaultName -secretName $resource.secretName
}

$parameterFileName = "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\Invoke-RemoveProcess.ps1" -projectsParameterFile $projectsParameterFile -parameterFileName $parameterFileName