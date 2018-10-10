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
    $ref = ($resource.parameters | Where-Object { $_.name -eq "masterClientIdPassword"}).ref
    if ($null -ne $ref) {
        $ref.secretName = Get-FormatedText -strFormat $ref.secretName
    }
}

$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\Invoke-NewProcess.ps1" -projectsParameterFile $projectsParameterFile -resourceType (Get-Item -Path $PSScriptRoot).Parent.Name -parameterFileName "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
