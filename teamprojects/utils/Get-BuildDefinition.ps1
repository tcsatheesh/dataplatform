param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile,

    [Parameter(Mandatory = $True, HelpMessage = 'The personal access token used to authorize vsts requests')]
    [String]$personalAccessToken
)

function Get-Resource {
    param (
        [object]$resource
    )
    $vstsAccountName = $resource.vstsAccountName
    $vstsTeamProjectName = $resource.vstsTeamProjectName
    $vstsTeamProjectCIBuildDefinitionName = $resource.vstsTeamProjectCIBuildDefinitionName
    $vstsTeamProjectScheduledBuildDefinitionName = $resource.vstsTeamProjectScheduledBuildDefinitionName

    function Get-BuildDef {
        param
        (
            [string]$vstsTeamProjectBuildDefinitionName
        )
        $patString = "{0}:{1}" -f "", $personalAccessToken
        $base64PatString = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($patString))

        try {
            $vstsURL = "https://{0}.visualstudio.com/DefaultCollection/{1}/_apis/build/definitions?api-version=2.0" -f $vstsAccountName, $vstsTeamProjectName
            $params = @{    
                ContentType = 'application/json'
                Headers     = @{
                    'Authorization' = "Basic $base64PatString"
                }
                Method      = 'Get'    
                URI         = $vstsURL
            }
            Write-Verbose "Getting the build definitions for team project $vstsTeamProjectName"
            $authZResponse = Invoke-RestMethod @params
            $vstsTeamProjectBuildDefinitionId = ($authZResponse.value | Where-Object {$_.name -eq $vstsTeamProjectBuildDefinitionName}).id
            Write-Verbose "Build Definition id for build $vstsTeamProjectBuildDefinitionName is $vstsTeamProjectBuildDefinitionId"        

            $vstsURL = "https://{0}.visualstudio.com/DefaultCollection/{1}/_apis/build/definitions/{2}?api-version=2.0" -f $vstsAccountName, $vstsTeamProjectName, $vstsTeamProjectBuildDefinitionId
            $params = @{    
                ContentType = 'application/json'
                Headers     = @{
                    'Authorization' = "Basic $base64PatString"
                }
                Method      = 'Get'    
                URI         = $vstsURL
            }
            $authZResponse = Invoke-RestMethod @params
            return $authZResponse
        }
        catch {
            Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
            Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
            throw
        }
    }

    Get-BuildDef -vstsTeamProjectBuildDefinitionName $vstsTeamProjectCIBuildDefinitionName
    Get-BuildDef -vstsTeamProjectBuildDefinitionName $vstsTeamProjectScheduledBuildDefinitionName
}

$parameterFileName = "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\Invoke-GetProcess.ps1" -projectsParameterFile $projectsParameterFile -parameterFileName $parameterFileName