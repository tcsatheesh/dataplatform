param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile,

    [Parameter(Mandatory = $True, HelpMessage = 'The text to format.')]
    [string]$strFormat
)

$projectParameterFileFullPath = (Get-Item -Path $projectsParameterFile).FullName
$projectParameters = Get-Content -Path $projectParameterFileFullPath -Raw | ConvertFrom-Json
function Get-Resource {
    param (
        [string]$type
    )
    $resource = $projectParameters.parameters.resources.value | Where-Object {$_.type -eq $type}
    return $resource.name
}

$department = Get-Resource -type "department"
$projectName = Get-Resource -type "projectName"
$environment = Get-Resource -type "environment"
$tenant = Get-Resource -type "tenant"

$returnValue = $strFormat -f $department, $projectName, $environment, $tenant
return $returnValue