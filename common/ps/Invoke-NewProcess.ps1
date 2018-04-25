param(
    [string]$projectsParameterFile,
    [string]$resourceType,
    [string]$parameterFileName,
    [scriptblock]$procToRun
)

function Get-FormatedText {
    param(
        [string]$strFormat
    )

    $commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
    $name = & "$commonPSFolder\Get-FormatedText.ps1" `
        -projectsParameterFile $projectsParameterFile `
        -strFormat $strFormat
    return $name
}

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

$commonPSFolder = (Get-Item -Path $PSScriptRoot).FullName
$parameters = & "$commonPSFolder\Get-TemplateParameters.ps1" `
    -resourceType $resourceType -parameterFileName $parameterFileName 

& $procToRun

& "$commonPSFolder\Update-ProjectParameters.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -parameters $parameters -parameterFileName $parameterFileName

