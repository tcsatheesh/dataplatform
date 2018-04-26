param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function Remove-ChildResources {
    Write-Verbose "Post-removing resource $($resource.name)"
    $param = $resource.parameters | Where-Object {$_.name -eq "serverName" }
    $serverName = $param.value
    Write-Verbose "Server name is $serverName"
    $resourceGroup = Get-ResourceGroup -resourceGroupTypeRef $resource.resourceGroupTypeRef
    Remove-AzureResource -resourceGroup $resourceGroup -Name $serverName
}


$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName

& "$commonPSFolder\Remove-Resources.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -resourceType "sqldbs" `
    -postRemoveProcToRun {Remove-ChildResources}
