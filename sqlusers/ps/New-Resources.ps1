param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function New-Resource {
    param (
        [object]$resource
    )
    $resource.name = Get-FormatedText -strFormat $resource.name
    $parameters = $resource.parameters | Where-Object {$_.type -eq "format"}
    foreach ($parameter in $parameters) {
        Write-Verbose "Formatting $($parameter.name)"
        $parameter.value = Get-FormatedText -strFormat $parameter.value
    }
    $parameters = $resource.parameters | Where-Object {$_.type -eq "keyvaultsecret"}
    foreach ($parameter in $parameters) {
        Write-Verbose "Formatting $($parameter.name)"
        $parameter.ref.secretName = Get-FormatedText -strFormat $parameter.ref.secretName
    }
}

function New-Resources {
    foreach ($resource in $parameters.parameters.resources.value) {
        Write-Verbose "Processing resource $($resource.name)"
        New-Resource -resource $resource
    }
}

$resourceType = (Get-Item -path $PSScriptRoot).Parent.Name

$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
$parameterFileName = "$resourceType.parameters.json"

& "$commonPSFolder\Invoke-NewProcess.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -resourceType $resourceType `
    -parameterFileName $parameterFileName `
    -procToRun {New-Resources}
