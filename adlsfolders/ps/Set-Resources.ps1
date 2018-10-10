param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function Set-FolderPermissions {
    param
    (
        [string]$adlStoreName,
        [object] $folders
    )    
    $folderName = $folders.folderName
    foreach ($objP in $folders.permissions) {
                
        $objectId = $objP.Id
        $aadName = $objP.AADName
        $permission = $objP.Permission
        $aceType = $objP.AceType

        if ([string]::IsNullOrEmpty($objectId)) {
            Write-Verbose "AceType $($objP.AceType) has no object Id"
        }
        else {
            Write-Verbose "Granting $aceType $aadName with Id $objectId permissions $permission to folder $folderName"
            if ($objP.Default -eq "true") {
                Set-AzureRmDataLakeStoreItemAclEntry -Account $adlStoreName -Path $folderName -AceType $aceType -Id $objectId -Permissions $permission -Default
            }
            else {
                Set-AzureRmDataLakeStoreItemAclEntry -Account $adlStoreName -Path $folderName -AceType $aceType -Id $objectId -Permissions $permission
            }        
        }
    }
}

function Set-Resource {
    param (
        [object]$resource
    )
    $adlStoreName = $resource.adlStoreName
    foreach ($obj in $resource.folders) {
        if (-not ("/".Equals($obj.folderName))) {
            Try {
                # Create the folder so long as it doesn't already exist.
                if (!(Get-AzureRmDataLakeStoreItem -AccountName $adlStoreName -Path $obj.folderName -ErrorAction Ignore)) {
                    $null = New-AzureRmDataLakeStoreItem -Folder -AccountName $adlStoreName -Path $obj.folderName
                }            
            }
            Catch {
                Write-Error $_.Exception.Message
            }
        }
        Set-FolderPermissions -adlStoreName $adlStoreName -folders $obj
    }
}

$parameterFileName = "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\Invoke-SetProcess.ps1" -projectsParameterFile $projectsParameterFile -parameterFileName $parameterFileName
