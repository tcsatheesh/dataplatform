param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function Remove-ChildResources {
    Write-Verbose "Pre-removing resource $($resource.name)"
    $osdiskName = "$($resource.name)-os"
    $lun0diskName = "$($resource.name)-lun0"
    $nicName = "$($resource.name)-nic"
    $resourceGroup = Get-ResourceGroup -resourceGroupTypeRef $resource.resourceGroupTypeRef
    Remove-AzureResource -resourceGroup $resourceGroup -Name $osdiskName
    Remove-AzureResource -resourceGroup $resourceGroup -Name $lun0diskName
    Remove-AzureResource -resourceGroup $resourceGroup -Name $nicName
}

$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName

& "$commonPSFolder\Remove-Resources.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -resourceType (Get-Item -Path $PSScriptRoot).Parent.Name `
    -postRemoveProcToRun {Remove-ChildResources}