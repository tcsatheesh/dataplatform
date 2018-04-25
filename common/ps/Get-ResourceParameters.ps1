param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile,
    
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$parameterFileName
)

$projectFolder = (Get-Item -Path $projectsParameterFile).DirectoryName
$projectParameterFullPath = "$projectFolder\$parameterFileName"
Write-Verbose "Project Parameter Full Path: $projectParameterFullPath"
if (-not (Test-Path -Path $projectParameterFullPath)) {
    throw "Project parameter file not found in $projectParameterFullPath"
}
$projectParameterFullPath = (Get-Item -Path $projectParameterFullPath).FullName
Write-Verbose "Project Parameter Full Path: $projectParameterFullPath"
$parameters = Get-Content -Path $projectParameterFullPath -Raw | ConvertFrom-JSON
return $parameters 
