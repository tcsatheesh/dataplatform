param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function Remove-Resource {
    param (
        [object]$resource
    )
    $dataFactoryResourceGroupName = Get-ValueFromResource `
        -resourceType "resourcegroups" `
        -typeFilter $resource.dataFactoryResourceGroupTypeRef `
        -property "name"

    $dataFactoryName = Get-ValueFromResource `
        -resourceType "adfs" `
        -typeFilter $resource.dataFactoryNameRef `
        -property "name"
            
    $linkedServiceName = Get-ValueFromResource `
        -resourceType $resource.name.ref.resourceType `
        -typeFilter $resource.name.ref.typeFilter `
        -property $resource.name.ref.property

    Write-Verbose "Removing linked service $linkedServiceName"
        
    $depl = Remove-AzureRmDataFactoryV2LinkedService `
        -ResourceGroupName  $dataFactoryResourceGroupName `
        -DataFactoryName $dataFactoryName `
        -Name $linkedServiceName -Force
}

function Remove-Resources {
    param (
        [object]$parameters
    )
    $resources = $parameters.parameters.resources.value
    $index = $resources.Length - 1
    foreach ($r in $resources) {
        $resource = $resources[$index--]
        Write-Verbose "Removing resource $resource"
        Remove-Resource -resource $resource
    }
}

$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
. "$commonPSFolder\Get-CommonFunctions.ps1"

$projectFolder = (Get-Item -Path $projectsParameterFile).DirectoryName
$linkedServiceParametersFile = "$projectFolder\linkedservices\$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
$parameters = Get-Content $linkedServiceParametersFile -Raw | ConvertFrom-Json
Remove-Resources -parameters $parameters

