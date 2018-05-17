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
    if ($param -ne $null) {
        $resourcename = $param.value
        Write-Verbose "Resource name is $resourcename"
        $resourceGroup = Get-ResourceGroup -resourceGroupTypeRef $resource.resourceGroupTypeRef
        Remove-AzureResource -resourceGroup $resourceGroup -Name $resourcename    
    }
}

function Remove-ChildResources {
    Write-Verbose "Post-removing resource $($resource.name)"
    Remove-AzResource -resource $resource -name "appinsightsname"
    Remove-AzResource -resource $resource -name "hostingPlanName"
    Remove-AzResource -resource $resource -name "sslCertName"
}

$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
$resourceType = (Get-Item -Path $PSScriptRoot).Parent.Name
& "$commonPSFolder\Remove-Resources.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -resourceType $resourceType `
    -postRemoveProcToRun {Remove-ChildResources}