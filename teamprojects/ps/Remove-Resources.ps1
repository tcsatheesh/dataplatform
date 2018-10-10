param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile,

    [Parameter(Mandatory = $True, HelpMessage = 'The personal access token used to authorize vsts requests')]
    [String]$personalAccessToken
)


function Remove-ReleaseDefinition {
    param (
        [object]$resource
    )

    $vstsAccountName = $resource.vstsAccountName
    $vstsTeamProjectName = $resource.vstsTeamProjectName
    $vstsTeamProjectCIReleaseDefinitionName = $resource.vstsTeamProjectCIReleaseDefinitionName
    $vstsTeamProjectScheduledReleaseDefinitionName = $resource.vstsTeamProjectScheduledReleaseDefinitionName

    function Remove-Release {
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

            if ($vstsTeamProjectReleaseDefinitionId -eq $null) {
                Write-Warning "Release definition $vstsTeamProjectReleaseDefinitionName does not exist in the team project $vstsTeamProjectName"
            }
            else {
                Write-Verbose "Release Definition id for build $vstsTeamProjectReleaseDefinitionName is $buildDefinitionId"

                $vstsURL = "https://{0}.vsrm.visualstudio.com/DefaultCollection/{1}/_apis/release/definitions/{2}?api-version=3.0-preview.1" -f $vstsAccountName, $vstsTeamProjectName, $vstsTeamProjectReleaseDefinitionId
                $params = @{    
                    ContentType = 'application/json'
                    Headers     = @{
                        'Authorization' = "Basic $base64PatString"
                    }
                    Method      = 'Delete'    
                    URI         = $vstsURL
                }
                $authZResponse = Invoke-RestMethod @params
            }
        }
        catch {
            Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
            Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
            throw
        }
    }

    Remove-Release -vstsTeamProjectReleaseDefinitionName $vstsTeamProjectCIReleaseDefinitionName
    Remove-Release -vstsTeamProjectReleaseDefinitionName $vstsTeamProjectScheduledReleaseDefinitionName
}

function Remove-ServiceEndPoint {
    param (
        [object]$resource
    )

    $vstsAccountName = $resource.vstsAccountName
    $vstsTeamProjectName = $resource.vstsTeamProjectName
    $vstsSourceControlDevBranch = $resource.vstsSourceControlDevBranch
    Write-Verbose "The default source control branch is $vstsSourceControlDevBranch"

    $patString = "{0}:{1}" -f "", $personalAccessToken
    $base64PatString = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($patString))

    try {
        $vstsURL = "https://{0}.visualstudio.com/DefaultCollection/{1}/_apis/distributedtask/serviceendpoints?api-version=3.0-preview.1" -f $vstsAccountName, $vstsTeamProjectName
        $params = @{    
            ContentType = 'application/json'
            Headers     = @{
                'Authorization' = "Basic $base64PatString"
            }
            Method      = 'Get'    
            URI         = $vstsURL
        }
        Write-Verbose "Getting the service point definitions for team project $vstsTeamProjectName"
        $authZResponse = Invoke-RestMethod @params    
        $vstsProjectARMServiceEndPoint = $authZResponse.value | Where-Object {$_.name -eq $vstsProjectARMServiceEndPointName}
        if ($vstsProjectARMServiceEndPoint -ne $null) {
            $vstsURL = "https://{0}.visualstudio.com/DefaultCollection/{1}/_apis/distributedtask/serviceendpoints/{2}?api-version=3.0-preview.1" -f $vstsAccountName, $vstsTeamProjectName, $vstsProjectARMServiceEndPoint.id
            $params = @{    
                ContentType = 'application/json'
                Headers     = @{
                    'Authorization' = "Basic $base64PatString"
                }
                Method      = 'Delete'
                URI         = $vstsURL
            }
            Write-Verbose "Getting the service point definitions for team project $vstsTeamProjectName"
            $authZResponse = Invoke-RestMethod @params
        }
    }
    catch {
        Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
        Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
        throw
    }

}

function Remove-BuildDefinition {
    param (
        [object]$resource
    )

    $vstsAccountName = $resource.vstsAccountName
    $vstsTeamProjectName = $resource.vstsTeamProjectName
    $vstsTeamProjectCIBuildDefinitionName = $resource.vstsTeamProjectCIBuildDefinitionName
    $vstsTeamProjectScheduledBuildDefinitionName = $resource.vstsTeamProjectScheduledBuildDefinitionName


    $patString = "{0}:{1}" -f "", $personalAccessToken
    $base64PatString = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($patString))

    function Remove-Project {
        param
        (
            [String]$vstsTeamProjectBuildDefinitionName
        )
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
            $buildDefinitionId = ($authZResponse.value | Where-Object {$_.name -eq $vstsTeamProjectBuildDefinitionName}).id

            if ($buildDefinitionId -eq $null) {
                Write-Warning "Build definition $vstsTeamProjectBuildDefinitionName does not exist in the team project $vstsTeamProjectName"
            }
            else {
                Write-Verbose "Build Definition id for build $vstsTeamProjectBuildDefinitionName is $buildDefinitionId"

                $vstsURL = "https://{0}.visualstudio.com/DefaultCollection/{1}/_apis/build/definitions/{2}?api-version=2.0" -f $vstsAccountName, $vstsTeamProjectName, $buildDefinitionId
                $params = @{
                    ContentType = 'application/json'
                    Headers     = @{
                        'Authorization' = "Basic $base64PatString"
                    }
                    Method      = 'Delete'    
                    URI         = $vstsURL
                }
                Write-Verbose "Deleting build defnition $vstsTeamProjectBuildDefinitionName"
                $authZResponse = Invoke-RestMethod @params
                Write-Verbose $authZResponse
            }
        }
        catch {
            Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
            Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
            throw
        }
    }

    Remove-Project -vstsTeamProjectBuildDefinitionName $vstsTeamProjectCIBuildDefinitionName
    Remove-Project -vstsTeamProjectBuildDefinitionName $vstsTeamProjectScheduledBuildDefinitionName
}

function Remove-TeamProject {
    param(
        [object]$resource
    )

    $vstsAccountName = $resource.vstsAccountName
    $vstsTeamProjectName = $resource.vstsTeamProjectName


    $patString = "{0}:{1}" -f "", $personalAccessToken
    $base64PatString = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($patString))

    try {
        $vstsURL = "https://{0}.visualstudio.com/DefaultCollection/_apis/projects/{1}?api-version=1.0" -f $vstsAccountName, $vstsTeamProjectName
        $params = @{    
            ContentType = 'application/json'
            Headers     = @{
                'Authorization' = "Basic $base64PatString"
            }
            Method      = 'Get'    
            URI         = $vstsURL
        }
        Write-Verbose "Getting the project id for team project $vstsTeamProjectName"
        $authZResponse = Invoke-RestMethod @params
        $prjId = $authZResponse.id
        Write-Verbose "Project id is : $prjId"
        $vstsURL = "https://{0}.visualstudio.com/DefaultCollection/_apis/projects/{1}?api-version=1.0" -f $vstsAccountName, $prjId

        $params = @{    
            ContentType = 'application/json'
            Headers     = @{
                'Authorization' = "Basic $base64PatString"
            }
            Method      = 'Delete'    
            URI         = $vstsURL
        }
        Write-Verbose "Deleting the team project $vstsTeamProjectName"
        Invoke-RestMethod @params
        Write-Verbose "Deleted the team project $vstsTeamProjectName"
    }
    catch {
        Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
        Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
        throw
    }
}

function Remove-Resource {
    param (
        [object]$resource
    )
    Remove-ReleaseDefinition -resource $resource
    Remove-ServiceEndPoint -resource $resource
    Remove-BuildDefinition -resource $resource
    Remove-TeamProject -resource $resource
}

$parameterFileName = "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\Invoke-RemoveProcess.ps1" -projectsParameterFile $projectsParameterFile -parameterFileName $parameterFileName