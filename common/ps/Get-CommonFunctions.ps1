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
    
    if ($item -eq $null ) {
        throw "1. item cannot be null here for resourceType $resourceType with typeFilter as $typeFilter and subtypeFilter as $subtypeFilter and property as $property"
    }
    $props = $property.Split(".")
    foreach ($prop in $props) {
        $item = $item.$prop
    }
    $val = $item
    if ($item -eq $null ) {
        throw "2. item cannot be null here for resourceType $resourceType with typeFilter as $typeFilter and subtypeFilter as $subtypeFilter and property as $property"
    }
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

function Get-FormatedText {
    param(
        [string]$strFormat
    )

    $commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
    $name = & "$commonPSFolder\Get-FormatedText.ps1" `
        -projectsParameterFile $projectsParameterFile `
        -strFormat $strFormat
    return $name
}
