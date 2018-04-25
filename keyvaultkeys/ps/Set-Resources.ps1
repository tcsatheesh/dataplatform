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

function Set-Resource {
    param (
        [object]$resource
    )

    $keyVaultName = Get-KeyVaultName -keyVaultType $resource.keyVaultType
    $expiryTerm = $resource.expiryTerm
    $expiry = (Get-Date -Date $resource.startdate).AddYears($expiryTerm)
    $key = Get-AzureKeyVaultKey -VaultName $keyVaultName -Name $resource.name -ErrorAction SilentlyContinue
    if ( $key -eq $null) {
        $kyvlt = Add-AzureKeyVaultKey -VaultName $keyVaultName -Name $resource.name -Destination $resource.destination -Expires $secretExpiry
        Write-Verbose "Secret $($resource.name) added to the key vault $keyVaultName"
    }
    else {
        Write-Verbose "Secret $($resource.name) exists in the key vault $keyVaultName."
    }
}

function Set-Resources {
    foreach ($resource in $parameters.parameters.resources.value) {
        Write-Verbose "Processing secret $($resource.name)"
        Set-Resource -resource $resource
    }
}

$parameterFileName = "keyvaultkeys.parameters.json"
$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
$null = & "$commonPSFolder\Invoke-SetProcess.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -parameterFileName $parameterFileName `
    -procToRun {Set-Resources}
