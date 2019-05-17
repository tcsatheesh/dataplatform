param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)


function Set-KeyVaultAccessForDataFactory {
    param (
        [object]$resource,
        [object]$resourceparam
    )

    $keyVaultResourceGroupName = Get-ResourceGroupName -resourceGroupTypeRef $resource.resourceGroupTypeRef
    $keyVault = $resource.parameters | Where-Object {$_.name -eq "keyVaultName"}
    $keyVaultName = Get-FormatedText -strFormat $keyVault.value
    Write-Verbose "Resource name = $($resource.name)"
    $adfServicePrincipalName = Get-FormatedText -strFormat $resource.name
    
    Write-Verbose "Key Vault ResourceGroup Name                 : $keyVaultResourceGroupName"
    Write-Verbose "Key Vault Name                               : $keyVaultName"
    Write-Verbose "ADF ServicePrincipal Name                    : $adfServicePrincipalName"

    $adfSp = Get-AzureRmADServicePrincipal -DisplayName $adfServicePrincipalName
    $objectId = $adfSp.Id
    Write-Verbose "ADF Service Principal Object Id              : $objectId"

    Set-AzureRmKeyVaultAccessPolicy -ResourceGroupName $keyVaultResourceGroupName -VaultName $keyVaultName -ObjectId $objectId -PermissionsToSecrets get -Verbose
}

function Set-ResourceSpecificParameters {
    param (
        [object]$resource,
        [object]$resourceparam
    )
    if ($resourceparam.name -eq "linkedServiceName") {
        $val = Get-FormatedText -strFormat $resourceparam.value
        Set-KeyVaultAccessForDataFactory -resource $resource -resourceparam $resourceparam
    }
    else {
        throw "resource param $($resourceparam.name) not supported"
    }
    return $val
}


$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\New-Resources.ps1" -projectsParameterFile $projectsParameterFile -resourceType (Get-Item -Path $PSScriptRoot).Parent.Name