param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function Remove-Resource {
    param (
        [object]$resource
    )
    
    $diagnosticsStorageAccountId = $resource.diagnosticsStorageAccount.id
    $resourceId = $resource.resource.id    
    $retentionInDays = $resource.diagnosticsStorageAccount.retentionInDays

    $null = Set-AzureRmDiagnosticSetting -ResourceId $resourceId -StorageAccountId $diagnosticsStorageAccountId -RetentionInDays $retentionInDays -Enabled $False
}

$parameterFileName = "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\Invoke-RemoveProcess.ps1" -projectsParameterFile $projectsParameterFile -parameterFileName $parameterFileName