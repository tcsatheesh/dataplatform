param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function Get-ResourceGroupName {
    param(
        [string]$resourceGroupTypeRef
    )

    $commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
    $groupParameterFileName = "resourcegroups.parameters.json"
    $parameters = & "$commonPSFolder\Get-ResourceParameters.ps1" `
        -projectsParameterFile $projectsParameterFile `
        -parameterFileName $groupParameterFileName
    $resourceGroup = $parameters.parameters.resources.value | Where-Object {$_.type -eq $resourceGroupTypeRef}
    Write-Verbose "Returning $($resourceGroup.name) for resourceGroupTypeRef $resourceGroupTypeRef"
    return $resourceGroup.name
}

function Set-Resource {
    param (
        [object]$resource
    )

    $projectRootFolder = (Get-Item -Path $projectsParameterFile).DirectoryName
    $parameterFileName = $resource.parameterFileName
    $parameterFile = "$projectRootFolder\$($resource.resourceType)\$parameterFileName"
    $templateParameters = Get-Content -Path $parameterFile -Raw | ConvertFrom-Json

    $resourceGroupName = Get-ResourceGroupName -resourceGroupTypeRef $resource.resourceGroupTypeRef
    $VMName = $resource.name

    $keyVaultResourceGroupName = $templateParameters.parameters.keyVaultResourceGroup.value
    $keyVaultName = $templateParameters.parameters.keyVaultName.value
    $keyEncryptionKeyUrl = $templateParameters.parameters.keyEncryptionKeyURL.value
    $aadClientID = $templateParameters.parameters.aadClientID.value
    $KeyVaultResourceId = $templateParameters.parameters.aadClientSecret.reference.keyVault.id
    $keyVaultadAppSecretName = $templateParameters.parameters.aadClientSecret.reference.secretName
    Write-Verbose "secretName is $keyVaultadAppSecretName"
    $secret = Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name $keyVaultadAppSecretName

    Write-Verbose "Client ID is $aadClientID"
    $keyVault = Get-AzureRmKeyVault -ResourceGroupName $keyVaultResourceGroupName -VaultName $keyVaultName
    $diskEncryptionKeyVaultUrl = $keyVault.VaultUri
    Write-Verbose "diskEncryptionKeyVaultUrl is $diskEncryptionKeyVaultUrl"
    Write-Verbose "KeyVaultResourceId is $KeyVaultResourceId"
    Write-Verbose "keyEncryptionKeyUrl is $keyEncryptionKeyUrl"

    Set-AzureRmVMDiskEncryptionExtension `
        -ResourceGroupName $resourceGroupName `
        -VMName $vmName -AadClientID $aadClientID `
        -AadClientSecret $secret.SecretValueText `
        -KeyEncryptionKeyUrl $keyEncryptionKeyUrl `
        -KeyEncryptionKeyVaultId $KeyVaultResourceId `
        -DiskEncryptionKeyVaultUrl $diskEncryptionKeyVaultUrl `
        -DiskEncryptionKeyVaultId $KeyVaultResourceId `
        -VolumeType All -skipVmBackup -Force `
        -SequenceVersion 7 `
        -Verbose
}

function Set-Resources {
    foreach ($resource in $parameters.parameters.resources.value) {
        Set-Resource -resource $resource
    }
}

$parameterFileName = "encryptvms.parameters.json"
$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
$null = & "$commonPSFolder\Invoke-SetProcess.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -parameterFileName $parameterFileName `
    -procToRun {Set-Resources}
