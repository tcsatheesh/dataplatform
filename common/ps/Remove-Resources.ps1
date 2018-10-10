param
(
    [String]$projectsParameterFile,  
    [String]$resourceType,
    [scriptblock]$preRemoveProcToRun,
    [scriptblock]$postRemoveProcToRun
)

function Get-ResourceGroup {
    param(
        [string]$resourceGroupTypeRef
    )
    $parameterFileName = "resourcegroups.parameters.json"
    $parameters = Get-ResourceParameters -parameterFileName $parameterFileName
    $resourceGroup = $parameters.parameters.resources.value | Where-Object {$_.type -eq $resourceGroupTypeRef}
    Write-Verbose "Returning $($resourceGroup.name) for resourceGroupTypeRef $resourceGroupTypeRef"
    return $resourceGroup
}

function Remove-AzureResource {
    param (
        [object]$resourceGroup,
        [string]$name
    )
    Write-Verbose "Removing Azure resorce $name from resource group $($resourceGroup.name)"
    $resGrp = Get-AzureRmResourceGroup -Name $resourceGroup.name -Location $resourceGroup.location -ErrorAction SilentlyContinue
    if ($resGrp -ne $null) {
        $resourceGroupName = $resourceGroup.name
        $res = Get-AzureRmResource -ResourceGroupName $resourceGroupName -ResourceName $name -ErrorAction SilentlyContinue
        if ($res -ne $null) {
            Write-Verbose "Removing $name from resource group $resourceGroupName"
            Remove-AzureRmResource -ResourceId $res.ResourceId -Force
        }
        else {
            Write-Verbose "$name does not exist in resource group $resourceGroupName"
        }
    }else {
        Write-Verbose "Azure resource group $($resourceGroup.name) is not present."
    }

}

function Remove-Resource {
    param(
        [object]$resource
    )
    try {
        if ($preRemoveProcToRun -ne $null) {
            & $preRemoveProcToRun
        }else {
            Write-Verbose "pre remove script not provided"
        }
    }
    catch {
        Write-Error $_.Exception.Message
        Write-Verbose "Failed to invoke pre remove script"
    }

    $resourceGroup = Get-ResourceGroup -resourceGroupTypeRef $resource.resourceGroupTypeRef
    Remove-AzureResource -resourceGroup $resourceGroup -Name $resource.name

    try {
        if ($postRemoveProcToRun -ne $null) {
            & $postRemoveProcToRun
        }else {
            Write-Verbose "post remove script not provided"
        }
    }
    catch {
        Write-Error $_.Exception.Message
        Write-Verbose "Failed to invoke post remove sript"
    }
}

$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
$null = & "$commonPSFolder\Invoke-RemoveProcess.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -parameterFileName "$resourceType.parameters.json"
