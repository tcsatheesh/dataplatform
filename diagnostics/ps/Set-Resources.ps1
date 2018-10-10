param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function Set-Resource {
    param (
        [object]$resource
    )    
    $diagnosticsStorageAccountId = $resource.diagnosticsStorageAccount.id
    $resourceId = $resource.resource.id    
    $retentionInDays = $resource.diagnosticsStorageAccount.retentionInDays

    $null = Set-AzureRmDiagnosticSetting -ResourceId $resourceId -StorageAccountId $diagnosticsStorageAccountId -RetentionInDays $retentionInDays -Enabled $True
}

$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\Invoke-SetProcess.ps1" -projectsParameterFile $projectsParameterFile -resourceType (Get-Item -Path $PSScriptRoot).Parent.Name -parameterFileName "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
