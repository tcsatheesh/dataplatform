param(
    [string]$projectsParameterFile,
    [string]$parameterFileName,
    [scriptblock]$procToRun
)

$commonPSFolder = (Get-Item -Path $PSScriptRoot).FullName
. "$commonPSFolder\Get-CommonFunctions.ps1"

function Get-Resources {
    param (
        [object]$parameters
    )
    foreach ($resource in $parameters.parameters.resources.value) {
        Write-Verbose "Set-Resources for $($resource.type) invoked $($resource.enabled)"
        if ($resource.enabled) {
            Write-Verbose "Getting resource $($resource.name)"
            Get-Resource $resource
            Write-Verbose "Got resource $($resource.name)"
        }
    }
}

Set-Subscription
$parameters = Get-ResourceParameters -parameterFileName $parameterFileName
Get-Resources -parameters $parameters
Update-ProjectParameters -parameters $parameters -parameterFileName $parameterFileName
