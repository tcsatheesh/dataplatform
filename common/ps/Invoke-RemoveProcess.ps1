param(
    [string]$projectsParameterFile,
    [string]$parameterFileName
)


$commonPSFolder = (Get-Item -Path $PSScriptRoot).FullName
. "$commonPSFolder\Get-CommonFunctions.ps1"

function Remove-Resources {
    param (
        [object]$parameters
    )
    $resources = $parameters.parameters.resources.value
    $index = $resources.Length - 1
    foreach ($r in $resources) {
        $resource = $resources[$index--]
        if ( $resource.enabled ) {
            Write-Verbose "Removing resource: $($resource.type)"
            Remove-Resource -resource $resource
        }
        else {
            Write-Verbose "Skipping removing resource: $($resource.type)"
        }
    }
}

Set-Subscription
Write-Verbose "Parameter file name is $parameterFileName"
$parameters = Get-ResourceParameters -parameterFileName $parameterFileName
Remove-Resources -parameters $parameters

