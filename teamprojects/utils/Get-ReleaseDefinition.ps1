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

    $vstsTeamProjectCIReleaseDefinitionName = $parameters.parameters.vstsTeamProjectCIReleaseDefinitionName.value
    $vstsTeamProjectScheduledReleaseDefinitionName = $parameters.parameters.vstsTeamProjectScheduledReleaseDefinitionName.value

    function Get-ReleaseDef {
        param
        (
            [string]$vstsTeamProjectReleaseDefinitionName
        )
        $patString = "{0}:{1}" -f "", $personalAccessToken
        $base64PatString = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($patString))

        try {
            $vstsURL = "https://{0}.vsrm.visualstudio.com/DefaultCollection/{1}/_apis/release/definitions?api-version=3.0-preview.1" -f $vstsAccountName, $vstsTeamProjectName
            $params = @{    
                ContentType = 'application/json'
                Headers     = @{
                    'Authorization' = "Basic $base64PatString"
                }
                Method      = 'Get'    
                URI         = $vstsURL
            }
            Write-Verbose "Getting the release definitions for team project $vstsTeamProjectName"
            $authZResponse = Invoke-RestMethod @params
            $vstsTeamProjectReleaseDefinitionId = ($authZResponse.value | Where-Object {$_.name -eq $vstsTeamProjectReleaseDefinitionName}).id
            Write-Verbose "Release Definition id for build $vstsTeamProjectReleaseDefinitionName is $vstsTeamProjectReleaseDefinitionId"        

            $vstsURL = "https://{0}.vsrm.visualstudio.com/DefaultCollection/{1}/_apis/release/definitions/{2}?api-version=3.0-preview.2" -f $vstsAccountName, $vstsTeamProjectName, $vstsTeamProjectReleaseDefinitionId
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

    Get-ReleaseDef -vstsTeamProjectReleaseDefinitionName $vstsTeamProjectCIReleaseDefinitionName
    Get-ReleaseDef -vstsTeamProjectReleaseDefinitionName $vstsTeamProjectScheduledReleaseDefinitionName
}

$parameterFileName = "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\Invoke-GetProcess.ps1" -projectsParameterFile $projectsParameterFile -parameterFileName $parameterFileName
