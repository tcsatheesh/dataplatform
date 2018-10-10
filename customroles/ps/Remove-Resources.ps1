param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function Remove-Resource {
    param(
        [object]$resource
    )
    $resourceType = (Get-Item -Path $PSScriptRoot).Parent.Name
    $resourceParameterFileName = $resource.path
    $projectFolder = (Get-Item -Path $projectsParameterFile).DirectoryName
    $resourceParameters = Get-Content -Path "$projectFolder\$resourceType\$resourceParameterFileName" -Raw | ConvertFrom-Json
    $name = $resourceParameters.Name
    $rdef = Get-AzureRmRoleDefinition -Name $name -ErrorAction SilentlyContinue
    if ($rdef -eq $null) {
        Write-Verbose "Role definition $name does not exist"
    }
    else {
        Write-Verbose "Role definition $name exists. Removing..."
        Remove-AzureRmRoleDefinition -Id $rdef.Id -Force
    }
}

$parameterFileName = "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\Invoke-RemoveProcess.ps1" -projectsParameterFile $projectsParameterFile -parameterFileName $parameterFileName
