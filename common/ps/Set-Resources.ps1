param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile,
    
    [Parameter(Mandatory = $True, HelpMessage = 'The type of resource.')]
    [String]$resourceType
)

function Set-Resource {
    param(
        [object]$resource
    )
    $resourceGroupName = Get-ResourceGroupName -resourceGroupTypeRef $resource.resourceGroupTypeRef
    $deploymentName = "$($resource.name)-depl".Replace("/","-")
    $templateFile = Get-ProjectTemplateFilePath -resourceType $resource.ResourceType -fileName $resource.templateFileName
    $templateParameterFile = Get-ProjectTemplateFilePath -resourceType $resource.ResourceType -fileName $resource.parameterFileName

    Write-Verbose "DeploymentName is $deploymentName"
    Write-Verbose "Template file is $templateFile"
    Write-Verbose "Template parameter file is $templateParameterFile"
    Write-Verbose "resourceGroupName is $resourceGroupName"
    New-AzureRmResourceGroupDeployment -Name $deploymentName `
        -ResourceGroupName $resourceGroupName `
        -TemplateFile $templateFile `
        -TemplateParameterFile $templateParameterFile
}

$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName

$null = & "$commonPSFolder\Invoke-SetProcess.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -parameterFileName "$resourceType.parameters.json" `
    -procToRun {Set-Resources}
