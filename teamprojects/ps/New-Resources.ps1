param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile,
    
    [Parameter(Mandatory = $True, HelpMessage = 'The runas role.')]
    [string]$runas
)

function New-Resource {
    param (
        [object]$resource
    )
    $projectParameter = Get-ProjectParameter -type "vstsaccount"
    if ($projectParameter -eq $null) {
        throw "vstsacount info not set in projects.parameters.json"
    }
    else {
        Write-Verbose "Vsts account is $($projectParameter.name) and branch is $($projectParameter.branch)"
    }
    $branchname = $projectParameter.branch
    $resource.vstsAccountName = $projectParameter.name
    $resource.vstsTeamProjectName = Get-FormatedText -strFormat $resource.vstsTeamProjectName
    $resource.vstsSourceControlDevBranch = $branchname
    $resource.vstsTeamProjectCIBuildDefinitionName = "{0}_{1}" -f $branchname, $resource.vstsTeamProjectCIBuildDefinitionName
    $resource.vstsTeamProjectScheduledBuildDefinitionName = "{0}_{1}" -f $branchname, $resource.vstsTeamProjectScheduledBuildDefinitionName
    $resource.vstsTeamProjectCIReleaseDefinitionName = "{0}_{1}" -f $branchname, $resource.vstsTeamProjectCIReleaseDefinitionName
    $resource.vstsTeamProjectScheduledReleaseDefinitionName = "{0}_{1}" -f $branchname, $resource.vstsTeamProjectScheduledReleaseDefinitionName
    $resource.vstsProjectARMServiceEndPointName = Get-FormatedText -strFormat $resource.vstsProjectARMServiceEndPointName
}

$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName

& "$commonPSFolder\Invoke-NewProcess.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -resourceType (Get-Item -Path $PSScriptRoot).Parent.Name `
    -parameterFileName "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json" `
    -runas $runas

