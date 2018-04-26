param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile,
    
    [Parameter(Mandatory = $True, HelpMessage = 'The type of resource.')]
    [String]$resourceType
)

function Get-ResourceGroupName {
    param(
        [string]$resourceGroupTypeRef
    )

    $commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
    $groupParameterFileName = "resourcegroups.parameters.json"
    $parameters = & "$commonPSFolder\Get-ResourceParameters.ps1" `
        -projectsParameterFile $projectsParameterFile `
        -parameterFileName $groupParameterFileName
    $resourceGroup = $parameters.parameters.resources.value | Where-Object {$_.type -eq $resourceGroupTypeRef}
    Write-Verbose "Returning $($resourceGroup.name) for resourceGroupTypeRef $resourceGroupTypeRef"
    return $resourceGroup.name
}

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

    New-AzureRmResourceGroupDeployment -Name $deploymentName `
        -ResourceGroupName $resourceGroupName `
        -TemplateFile $templateFile `
        -TemplateParameterFile $templateParameterFile
}

function Set-Resources {
    foreach ($resource in $parameters.parameters.resources.value) {
        $enabled = $resource.enabled
        if ($enabled -ne $null) {            
            $enabled = [System.Convert]::ToBoolean($resource.enabled)   
        }else{
            $enabled = $true
        }
        if ( $enabled ) {
            Write-Verbose "Deploying resource: $($resource.name)"
            Set-Resource -resource $resource
        }else {
            Write-Verbose "Skipping deploying resource: $($resource.name)"
        }
    }
}

$parameterFileName = "$resourceType.parameters.json"
$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
$null = & "$commonPSFolder\Invoke-SetProcess.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -parameterFileName $parameterFileName `
    -procToRun {Set-Resources}
