param(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [string]$projectsParameterFile,
    [Parameter(Mandatory = $True, HelpMessage = 'The resource type.')]
    [string]$resourceType,
    [Parameter(Mandatory = $True, HelpMessage = 'The parameter file for the resource type.')]
    [string]$parameterFileName
    
)

$commonPSFolder = (Get-Item -Path $PSScriptRoot).FullName 
. "$commonPSFolder\Get-CommonFunctions.ps1"

$parameters = Get-TemplateParameters -resourceType $resourceType -parameterFileName $parameterFileName 
$projectsParameterFileName = "projects.parameters.json"
if (-not [string]::Equals($projectsParameterFileName.toLower(), $parameterFileName.toLower())) {
    $projectParameters = Get-ResourceParameters -parameterFileName $projectsParameterFileName
    $environment = $projectParameters.parameters.resources.value | Where-Object {$_.type -eq "envtype"}
    $selectedreslist = $projectParameters.parameters.resources.value | Where-Object {$_.type -eq $environment.value}
    $resourceTypedef = $selectedreslist.resources | Where-Object {$_.resourceType -eq $resourceType}
    $parameters.parameters.resources.value | ForEach-Object { if ($_.enabled -eq $null) {$_ | Add-Member -Name 'enabled' -MemberType Noteproperty -Value $false} else {$_.enabled = $false} }
    if ($resourceTypedef.resources.subtype -ne $null) {
        $selectedresources = $parameters.parameters.resources.value | Where-Object {$_.type -in $resourceTypedef.resources.type -and $_.subtype -in $resourceTypedef.resources.subtype}
    }
    else {
        $selectedresources = $parameters.parameters.resources.value | Where-Object {$_.type -in $resourceTypedef.resources.type}
    }
    if ($selectedresources -eq $null) {
        Write-Verbose "No resource selected. Exiting..."
        exit
    }
    Write-Verbose "Selected resources $selectedresources"
    $selectedresources | ForEach-Object {$_.enabled = $true}
    $parameters.parameters.resources.value = $selectedresources
}

function New-Resources {
    param (
        [object]$parameters
    )    
    foreach ($resource in $parameters.parameters.resources.value) {
        Write-Verbose "===== Resource $($resource.type) is enabled: $($resource.enabled) ====="
        if ($resource.enabled) {
            Write-Verbose "Processing new resource $($resource.type)"
            New-Resource $resource
            Write-Verbose "Processed new resource $($resource.type)"
        }else{
            Write-Verbose "Skipping resource $($resource.type)"
        }
    }
}

New-Resources -parameters $parameters

Update-ProjectParameters -parameters $parameters -parameterFileName $parameterFileName

