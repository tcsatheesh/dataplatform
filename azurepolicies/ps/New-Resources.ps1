
param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function New-Resource {
    param(
        [object]$resource
    )
    $resourceType = (Get-Item -Path $PSScriptRoot).Parent.Name

    $assignment = $resource.parameters | Where-Object {$_.type -eq "assignment"}
    if ($assignment -eq $null) {throw "Assignment is empty"}
    $subnetIdConfig = $assignment.parameters | Where-Object {$_.name -eq "subnetIds"}
    $subnetIds = @()
    foreach ($subnetIdRef in $subnetIdConfig.value) {
        Write-Verbose "SubnetIdRef is $subnetIdRef"
        $subnetId = Get-SubnetID -subnetRef $subnetIdRef
        $subnetIds += $subnetId
    }
    $subnetIdConfig.value = $subnetIds

    $resourceTemplateFileName = $resource.templateFileName  
    Copy-TemplateFile -resourceType $resourceType -templateFileName $resourceTemplateFileName
    if ($resource.subtype -eq "policy") {
        $resourceTemplateParameterFileName = $resource.templateParameterFileName
        Copy-TemplateFile -resourceType $resourceType -templateFileName $resourceTemplateParameterFileName
    }

}

$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\Invoke-NewProcess.ps1" -projectsParameterFile $projectsParameterFile -resourceType (Get-Item -Path $PSScriptRoot).Parent.Name -parameterFileName "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"



