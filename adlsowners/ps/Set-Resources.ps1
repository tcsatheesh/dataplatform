param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function Get-ADLStoreName {
    param(
        [string]$adlstoreType
    )

    $parameterFileName = "adlstores.parameters.json"
    $parameters = Get-ResourceParameters -parameterFileName $parameterFileName
    $adlstore = $parameters.parameters.resources.value | Where-Object {$_.type -eq $adlstoreType}
    return $adlstore.name
}

function Get-ADGroupObjectId {
    param (
        [string]$adGroupType
    )
    $parameterFileName = "adgroups.parameters.json"
    $parameters = Get-ResourceParameters -parameterFileName $parameterFileName
    $adGroup = $parameters.parameters.resources.value | Where-Object {$_.type -eq $adGroupType}
    return $adGroup.id
}

function Set-Resources {
    foreach ($resource in $parameters.parameters.resources.value) {
        $groupId = Get-ADGroupObjectId -adGroupType $resource.adGroupType
        $adlStoreName = Get-ADLStoreName -adlstoreType $resource.adlstoreType
        $path = $resource.path
        Set-AzureRmDataLakeStoreItemOwner -Account $adlStoreName -Path $path -Type Group -Id $groupid -ErrorAction SilentlyContinue
        Set-AzureRmDataLakeStoreItemAclEntry -Account $adlStoreName -Path $path -AceType Group -Id $groupid -Permissions All -Default -ErrorAction SilentlyContinue
    }
}

$parameterFileName = "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
$null = & "$commonPSFolder\Invoke-SetProcess.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -parameterFileName $parameterFileName `
    -procToRun {Set-Resources}