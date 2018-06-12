param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile,
    
    [Parameter(Mandatory = $True, HelpMessage = 'The type of resource.')]
    [String]$resourceType
)

function Get-ProjectTemplateFilePath {
    param(
        [string]$resourceType,
        [string]$fileName
    )
    $projectFolder = (Get-Item -Path $projectsParameterFile).DirectoryName
    return (Get-Item -Path "$projectFolder\$resourceType\$fileName").FullName
}

function Set-Resource {
    param(
        [object]$resource
    )
    $resourceGroupName = Get-ResourceGroupName -resourceGroupTypeRef $resource.resourceGroupTypeRef
    $deploymentName = "$($resource.name)-depl".Replace("/","-")
    $templateFile = Get-ProjectTemplateFilePath -resourceType $resource.ResourceType -fileName $resource.templateFileName
    $templateParameterFile = Get-ProjectTemplateFilePath -resourceType $resource.ResourceType -fileName $resource.parameterFileName

    Write-Verbose "Template file is $templateFile"
    Write-Verbose "Template parameter file is $templateParameterFile"
    New-AzureRmResourceGroupDeployment -Name $deploymentName `
        -ResourceGroupName $resourceGroupName `
        -TemplateFile $templateFile `
        -TemplateParameterFile $templateParameterFile
}

function Set-Resources {
    foreach ($resource in $parameters.parameters.resources.value) {
        if ( $enabled ) {
            Write-Verbose "Deploying resource: $($resource.name)"
            Set-Resource -resource $resource
        }else {
            Write-Verbose "Skipping deploying resource: $($resource.name)"
        }
    }
}

$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName

$null = & "$commonPSFolder\Invoke-SetProcess.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -parameterFileName "$resourceType.parameters.json" `
    -procToRun {Set-Resources}
