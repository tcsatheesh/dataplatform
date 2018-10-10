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
    $patString = "{0}:{1}" -f "", $personalAccessToken
    $base64PatString = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($patString))
    try {
        $vstsURL = "https://{0}.visualstudio.com/DefaultCollection/{1}/_apis/distributedtask/queues?api-version=3.0-preview.1" -f $vstsAccountName, $vstsTeamProjectName
        $params = @{    
            ContentType = 'application/json'
            Headers     = @{
                'Authorization' = "Basic $base64PatString"
            }
            Method      = 'Get'    
            URI         = $vstsURL
        }
        Write-Verbose "Getting the queue definitions for team project $vstsTeamProjectName"
        $authZResponse = Invoke-RestMethod @params
        return $authZResponse
    }
    catch {
        throw
    }
}

$parameterFileName = "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\Invoke-GetProcess.ps1" -projectsParameterFile $projectsParameterFile -parameterFileName $parameterFileName