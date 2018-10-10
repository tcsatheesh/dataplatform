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

$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\Invoke-NewProcess.ps1" -projectsParameterFile $projectsParameterFile -resourceType (Get-Item -Path $PSScriptRoot).Parent.Name -parameterFileName "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
