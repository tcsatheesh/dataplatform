param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function Set-Resource {
    param (
        [object]$resource
    )
    $projectFolder = (Get-Item -Path $projectsParameterFile).DirectoryName
    $configFile = "$projectFolder\linkedservices\$($resource.templateFileName)"
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
     
    Write-Verbose "Set linked service $linkedServiceName"

    $depl = Set-AzureRmDataFactoryV2LinkedService `
        -ResourceGroupName  $dataFactoryResourceGroupName `
        -DataFactoryName $dataFactoryName `
        -Name $linkedServiceName `
        -DefinitionFile $configFile -Force
}

function Set-Resources {
    param (
        [object]$parameters
    )
    $storageServices = $parameters.parameters.resources.value
    foreach ($resource in $storageServices) {
        if (($resource.enabled -eq $null) -or ($resource.enabled -eq $true)) {
            Set-Resource -resource $resource
        }
        else
        {
            Write-Verbose "Skipping deployment of $($resource.name)"
        }
    }
}

$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
. "$commonPSFolder\Get-CommonFunctions.ps1"

$projectFolder = (Get-Item -Path $projectsParameterFile).DirectoryName
$linkedServiceParametersFile = "$projectFolder\linkedservices\$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
$parameters = Get-Content $linkedServiceParametersFile -Raw | ConvertFrom-Json
Set-Resources -parameters $parameters

