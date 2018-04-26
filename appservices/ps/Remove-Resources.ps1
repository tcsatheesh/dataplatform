param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function Remove-AzResource {
    param(
        [object]$resouce,
        [string]$name
    )

    $param = $resource.parameters | Where-Object {$_.name -eq $name }
    $resourcename = $param.value
    Write-Verbose "Resource name is $resourcename"
    $resourceGroup = Get-ResourceGroup -resourceGroupTypeRef $resource.resourceGroupTypeRef
    Remove-AzureResource -resourceGroup $resourceGroup -Name $resourcename
}

function Remove-ChildResources {
    Write-Verbose "Post-removing resource $($resource.name)"
    Remove-AzResource -resource $resource -name "appinsightsname"
    Remove-AzResource -resource $resource -name "hostingPlanName"
}

$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName

& "$commonPSFolder\Remove-Resources.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -resourceType "appservices" `
    -postRemoveProcToRun {Remove-ChildResources}