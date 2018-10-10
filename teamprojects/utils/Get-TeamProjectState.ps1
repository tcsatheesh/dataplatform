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
        do {
            $vstsURL = "https://{0}.visualstudio.com/DefaultCollection/_apis/projects?stateFilter=All&api-version=1.0" -f $vstsAccountName
            $params = @{    
                ContentType = 'application/json'
                Headers     = @{
                    'Authorization' = "Basic $base64PatString"
                }
                Method      = 'Get'    
                URI         = $vstsURL
            }
            $authZResponse = Invoke-RestMethod @params
            $vstsProjectState = ($authZResponse.value | Where-Object {$_.name -eq $vstsTeamProjectName}).state
            if ($vstsProjectState -eq $null) {
                Write-Output "Project $vstsTeamProjectName does not exist"   
                return
            }
            else {
                Write-Output "Project $vstsTeamProjectName state is $vstsProjectState"   
            }    
            if ($vstsProjectState -ne "wellFormed") {
                Start-Sleep -s 5
            }
            else {
                Write-Output "Project $vstsTeamProjectName is ready"
            }     
        } while ($vstsProjectState -ne "wellFormed")
    }
    catch {
        Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
        Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
        throw
    }
}

$parameterFileName = "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\Invoke-GetProcess.ps1" -projectsParameterFile $projectsParameterFile -parameterFileName $parameterFileName