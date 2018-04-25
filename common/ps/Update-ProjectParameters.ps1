param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile,

    [Parameter(Mandatory = $True, HelpMessage = 'The parameters object.')]
    [object]$parameters,
    
    [Parameter(Mandatory = $True, HelpMessage = 'The name of the parameter file.')]
    [string]$parameterFileName
)
Write-Verbose "Projects Parameter File $projectsParameterFile"
$projectFolder = (Get-Item -Path $projectsParameterFile).DirectoryName
Write-Verbose "Projects Folder $projectFolder"
$projectParameterFullPath = "$projectFolder\$parameterFileName"
Write-Verbose "Project Parameter Full Path: $projectParameterFullPath"
$parameters | ConvertTo-JSON -Depth 10 | Out-File -filepath $projectParameterFullPath -Force -Encoding utf8
Write-Verbose "Project parameter file updated at: $projectParameterFullPath"
