param(
    [string]$projectsParameterFile,
    [string]$parameterFileName
)

$commonPSFolder = (Get-Item -Path $PSScriptRoot).FullName
. "$commonPSFolder\Get-CommonFunctions.ps1"

function Set-Resources {
    param (
        [object]$parameters
    )
    foreach ($resource in $parameters.parameters.resources.value) {
        Write-Verbose "Set-Resources for $($resource.type) invoked $($resource.enabled)"
        if ($resource.enabled) {
            Write-Verbose "Processing resource $($resource.name)"
            Set-Resource $resource
            Write-Verbose "Processed resource $($resource.name)"
        }
    }
}

Set-Subscription
$parameters = Get-ResourceParameters -parameterFileName $parameterFileName
Set-Resources -parameters $parameters
Update-ProjectParameters -parameters $parameters -parameterFileName $parameterFileName
