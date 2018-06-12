param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile,
    
    [Parameter(Mandatory = $True, HelpMessage = 'The runas role.')]
    [string]$runas
)

function Get-Principal {
    param (
        [string]$type
    )
    $parameterFileName = "principals.parameters.json"
    $parameters = Get-ResourceParameters -parameterFileName $parameterFileName
    $resource = $parameters.parameters.resources.value | Where-Object {$_.type -eq $type}
    return $resource.servicePrincipal
}
function Get-ADGroup {
    param (
        [string]$type
    )
    $parameterFileName = "adgroups.parameters.json"
    $parameters = Get-ResourceParameters -parameterFileName $parameterFileName
    $resource = $parameters.parameters.resources.value | Where-Object {$_.type -eq $type}  
    return $resource 
}

function New-Resource {    
    param(
        [object]$resource
    )
    $resource.adlStoreName = Get-FormatedText $resource.adlStoreName

    foreach ($folder in $resource.folders) {
        $folderName = $folder.folderName
        Write-Verbose "Processing $folderName"
        foreach ($permission in $folder.permissions) {
            $aadName = $permission.AADName
            $aadType = $permission.AADType
            Write-Verbose "Permission in $folderName for $aadName"
            if ($aadType -eq "SPN") {
                $resource = Get-Principal -type $aadName
                $aadName = $resource.name
                $objectid = $resource.id
            } 
            else {
                $resource = Get-ADGroup -type $aadName
                $aadName = $resource.name
                $objectid = $resource.id
            }
            Write-Verbose "Processing folder $folderName for aad user $aadName"
            $permission.AADName = $aadName
            $permission.Id = $objectid        
        }
    }
}

$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName

& "$commonPSFolder\Invoke-NewProcess.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -resourceType (Get-Item -Path $PSScriptRoot).Parent.Name `
    -parameterFileName "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json" `
    -runas $runas