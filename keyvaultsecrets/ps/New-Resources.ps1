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

function New-Resource {
    param (
        [object]$resource
    )
    $parameters = $resource.parameters
    if ($resource.type -eq "storageconnectionstring") {
        $val = Get-ValueFromResourceRef -parameters $resource.parameters -type "storageAccountName"
        $val = $resource.name -f $val
    }
    elseif ($resource.type -eq "login") {
        $res = $resource.parameters | Where-Object {$_.name -eq "resourcename"}
        $resname = Get-FormatedText -strFormat $res.value
        $res.value = $resname
        $account = $resource.parameters | Where-Object {$_.name -eq "account"}            
        $val = $resource.name -f $resname, $account.value
    }
    elseif ($resource.type -eq "sqldbconnectionstring") { 
        $sqlServer = $resource.parameters | Where-Object {$_.name -eq "sqlServerName"}
        $sqlServerName = Get-FormatedText -strFormat $sqlServer.value
        $sqlServer.value = $sqlServerName
        $sqlDatabase = $resource.parameters | Where-Object {$_.name -eq "sqlDatabaseName"}
        $sqlDatabaseName = Get-FormatedText -strFormat $sqlDatabase.value
        $sqlDatabase.value = $sqlDatabaseName
        $account = $resource.parameters | Where-Object {$_.name -eq "account"}
        $val = $resource.name -f $sqlServerName, $account.value
    }
    else {
            Default {throw "resource type not defined"}
    }
    $resource.name = $val
}

function New-Resources {
    foreach ($resource in $parameters.parameters.resources.value) {
        Write-Verbose "Processing resource $($resource.name)"
        New-Resource $resource
        Write-Verbose "Processed resource $($resource.name)"
    }
}

$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
$parameterFileName = "keyvaultsecrets.parameters.json"

& "$commonPSFolder\Invoke-NewProcess.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -resourceType "keyvaultsecrets" `
    -parameterFileName $parameterFileName `
    -procToRun {New-Resources}
