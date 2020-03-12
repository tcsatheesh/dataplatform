param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function Remove-NestedResources {
    Write-Verbose "Pre-removing resource $($resource.name)"
    $param = $resource.parameters | Where-Object {$_.name -eq "workspaceName" }
    $workspaceName = "$($resource.name)"
    Write-Verbose "Workspace name is $workspaceName"
    $param = $resource.parameters | Where-Object {$_.name -eq "modelManagementAccountName" }
    $mmName = $param.value
    Write-Verbose "Model management name is $mmName "
    $resourceGroup = Get-ResourceGroup -resourceGroupTypeRef $resource.resourceGroupTypeRef
    Remove-AzureResource -resourceGroup $resourceGroup -Name $workspaceName
    Remove-AzureResource -resourceGroup $resourceGroup -Name $mmName
}

$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName

& "$commonPSFolder\Remove-Resources.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -resourceType (Get-Item -Path $PSScriptRoot).Parent.Name `
    -preRemoveProcToRun {Remove-NestedResources} 
