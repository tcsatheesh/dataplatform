param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function Get-Principal {
    param (
        [string]$type,
        [switch]$godeep
    )
    $parameterFileName = "principals.parameters.json"
    if ($godeep) {
        $parameters = Get-ResourceParameters -parameterFileName $parameterFileName -godeep
    }else {
        $parameters = Get-ResourceParameters -parameterFileName $parameterFileName
    }
    $resource = $parameters.parameters.resources.value | Where-Object {$_.type -eq $type}
    return $resource.servicePrincipal
}
function Get-ADGroup {
    param (
        [string]$type,
        [switch]$godeep
    )
    $parameterFileName = "adgroups.parameters.json"
    if ($godeep) {
        $parameters = Get-ResourceParameters -parameterFileName $parameterFileName -godeep
    }else {
        $parameters = Get-ResourceParameters -parameterFileName $parameterFileName
    }
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
        $permissionsToSet = @()
        foreach ($permission in $folder.permissions) {
            $aadName = $permission.AADName
            $aadType = $permission.AADType
            $objectid = $null
            Write-Verbose "Permission in $folderName for $aadName"
            if ($aadType -eq "SPN") {
                $principal = Get-Principal -type $aadName -godeep
                if ([string]::IsNullOrEmpty($principal)) {
                    Write-Verbose "Principal $aadName not defined"
                }
                else {
                    $aadName = $principal.name
                    $objectid = $principal.id
                }
            } 
            else {
                $group = Get-ADGroup -type $aadName -godeep
                if ([string]::IsNullOrEmpty($group)) {
                    Write-Verbose "Group $aadName not defined"
                }
                else {
                    $aadName = $group.name
                    $objectid = $group.id
                }
            }
            Write-Verbose "Processing folder $folderName for aad user $aadName"
            if (-not [string]::IsNullOrEmpty($objectid)) {
                $permission.AADName = $aadName
                $permission.Id = $objectid
                $permissionsToSet += $permission
                Write-Verbose "Permission to add $($permission)"
            }
            else
            {
                Write-Verbose "Permission not added $aadName"
            }
        }
        Write-Verbose "Permissions Count = $($permissionsToSet.Count)"
        $folder.permissions = $permissionsToSet
    }
}

$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\Invoke-NewProcess.ps1" -projectsParameterFile $projectsParameterFile -resourceType (Get-Item -Path $PSScriptRoot).Parent.Name -parameterFileName "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
