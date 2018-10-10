param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function Set-Resource {
    param(
        [object]$resource
    )
    $resourceType = (Get-Item -Path $PSScriptRoot).Parent.Name
    $resourceParameterFileName = $resource.path
    $templateFilePath = Get-ProjectTemplateFilePath -resourceType $resourceType -fileName $resourceParameterFileName
    $projectFolder = (Get-Item -Path $projectsParameterFile).DirectoryName
    $resourceParameters = Get-Content -Path "$projectFolder\$resourceType\$resourceParameterFileName" -Raw | ConvertFrom-Json
    $name = $resourceParameters.Name
    $rdef = Get-AzureRmRoleDefinition -Name $name -ErrorAction SilentlyContinue
    if ($rdef -ne $null -and $resource.update) {
        Write-Verbose "Updating role defintion for $name"
        $resourceParameters = Set-AzureRmRoleDefinition -InputFile $templateFilePath
    }
    elseif ($rdef -eq $null) {
        Write-Verbose "Creating role definition $name"
        $resourceParameters = New-AzureRmRoleDefinition -InputFile $templateFilePath
    }
    else {
        Write-Verbose "Role definition $name exists and not updated"
        return
    }
    
    Set-ParametersToFile -resourceType $resourceType `
        -parameters $resourceParameters `
        -parameterFileName $resourceParameterFileName
}

$parameterFileName = "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\Invoke-SetProcess.ps1" -projectsParameterFile $projectsParameterFile -parameterFileName $parameterFileName
