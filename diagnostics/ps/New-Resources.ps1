param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function New-Resource {
    param (
        [object]$resource
    )
    
    $diagnosticsStorageAccountName = Get-ValueFromResource `
        -resourceType $resource.diagnosticsStorageAccount.name.ref.resourceType `
        -typeFilter $resource.diagnosticsStorageAccount.name.ref.typeFilter `
        -property $resource.diagnosticsStorageAccount.name.ref.property

    $resourcename = Get-ValueFromResource `
        -resourceType $resource.resource.name.ref.resourceType `
        -typeFilter $resource.resource.name.ref.typeFilter `
        -property $resource.resource.name.ref.property
    
    $diagnosticsStorageAccount = Get-AzureRmStorageAccount | Where-Object {$_.StorageAccountName -eq $diagnosticsStorageAccountName}
    $resourcetoSet = Get-AzureRmResource | Where-Object {$_.Name -eq $resourcename}

    Write-Verbose "Diagnostics Storage Account Id is $($diagnosticsStorageAccount.Id)"
    Write-Verbose "Resource Id is $($resourcetoSet.ResourceId)"
    
    $resource.diagnosticsStorageAccount.name = $diagnosticsStorageAccountName
    $resource.diagnosticsStorageAccount.id = $diagnosticsStorageAccount.Id
    $resource.resource.name = $resourceName
    $resource.resource.id = $resourcetoSet.ResourceId
}

$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\Invoke-NewProcess.ps1" -projectsParameterFile $projectsParameterFile -resourceType (Get-Item -Path $PSScriptRoot).Parent.Name -parameterFileName "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
