param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function Get-ValueFromResource {
    param(
        [string]$resourceType,
        [string]$property,
        [string]$typeFilter,
        [string]$subtypeFilter
    )
    
    $projectFolder = (Get-Item -Path $projectsParameterFile).DirectoryName
    $itemPath = "$projectFolder\$resourceType.parameters.json"
    $parameters = Get-Content -Path $itemPath -Raw | ConvertFrom-Json
    
    if ([String]::IsNullOrEmpty($subtypeFilter)) {
        $item = $parameters.parameters.resources.value | Where-Object {$_.type -eq $typeFilter}
    }
    else {
        $item = $parameters.parameters.resources.value | `
            Where-Object {$_.type -eq $typeFilter -and $_.subtype -eq $subtypeFilter}
    }

    if ($item -eq $null) {
        throw "Item cannot be null here for type $type. 
         ResourceType $resourceType 
         Type Filter $typeFilter
         Property $property
         Sub Type Filter $subtypeFilter
        "
    }

    $props = $property.Split(".")
    foreach ($prop in $props) {
        $item = $item.$prop
        if ($item -eq $null) {
            throw "Item cannot be null for $prop"
        }
    }
    $val = $item
    return $val 
}

function Get-ValueFromResourceRef {
    param (
        [object]$parameters,
        [string]$type
    )
    $parameter = $parameters | Where-Object {$_.type -eq $type}
    $val = Get-ValueFromResource `
        -resourceType $parameter.ref.resourceType `
        -typeFilter $parameter.ref.typeFilter `
        -property $parameter.ref.property `
        -subtypeFilter $parameter.ref.subtypeFilter
    return $val
}

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

$projectFolder = (Get-Item -Path $projectsParameterFile).DirectoryName
$linkedServiceParametersFile = "$projectFolder\linkedservices\linkedservices.parameters.json"
$parameters = Get-Content $linkedServiceParametersFile -Raw | ConvertFrom-Json
Set-Resources -parameters $parameters

