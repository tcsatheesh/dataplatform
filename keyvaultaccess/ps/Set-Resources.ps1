param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function Set-Resource {
    param (
        [object]$resource
    )
    $keyVaultName = Get-KeyVaultName -keyVaultType $resource.keyVaultType
    Write-Verbose "Key Vault Name is $keyVaultName"
    $keyVaultResourceGroupName = Get-ResourceGroupName -resourceGroupTypeRef $resource.resourceGroupTypeRef
    Write-Verbose "Key Vault Resource Group Name is $keyVaultResourceGroupName"
    $objectIdObj = $resource.parameters | Where-Object {$_.type -eq "objectId"}
    Write-Verbose "ObjectID is $($objectIdObj.type)"
    $objectId = Get-ValueFromResource -resourceType $objectIdObj.ref.resourceType -property $objectIdObj.ref.property -typeFilter $objectIdObj.ref.typeFilter -subtypeFilter $objectIdObj.ref.subtypeFilter

    Set-AzureRmKeyVaultAccessPolicy -VaultName $keyVaultName -ResourceGroupName $keyVaultResourceGroupName -ObjectId $objectId -PermissionsToSecrets $objectIdObj.secrets
}

$parameterFileName = "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\Invoke-SetProcess.ps1" -projectsParameterFile $projectsParameterFile -parameterFileName $parameterFileName

