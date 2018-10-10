param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile,

    [Parameter(Mandatory = $True, HelpMessage = 'The personal access token used to authorize vsts requests')]
    [String]$personalAccessToken
)


function New-TeamProject {
    param
    (    
        [object]$resource
    )

    try {
        $jsonStr = @"
    {
        "name": "",
        "description": "",
        "capabilities": 
        {
            "versioncontrol": 
            {
                "sourceControlType": ""
            },
            "processTemplate": 
            {
                "templateTypeId": ""
            }
        }
    }
"@
        $vstsAccountName = $resource.vstsAccountName
        $vstsProjectTemplateType = $resource.vstsProjectTemplateType
        $vstsTeamProjectName = $resource.vstsTeamProjectName
        $vstsSourceControlType = $resource.vstsSourceControlType

        $patString = "{0}:{1}" -f "", $personalAccessToken
        $base64PatString = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($patString))

        $vstsURL = "https://{0}.visualstudio.com/DefaultCollection/_apis/projects?api-version=1.0" -f $vstsAccountName

        $vstsTeamProject = $jsonStr | ConvertFrom-JSON
        $vstsTeamProject.name = $vstsTeamProjectName
    
        if ("CMMI".ToLower().Equals($vstsProjectTemplateType.ToLower())) {
            $templateTypeId = "27450541-8e31-4150-9947-dc59f998fc01"
        }
        elseif ("Scrum".ToLower().Equals($vstsProjectTemplateType.ToLower())) {
            $templateTypeId = "6b724908-ef14-45cf-84f8-768b5384da45"
        }
        elseif ("Agile".ToLower().Equals($vstsProjectTemplateType.ToLower())) {
            $templateTypeId = "adcc42ab-9882-485e-a3ed-7678f01f66bc"        
        }
        else {
            throw "Template type $vstsProjectTemplateType is not a recognized template in VSTS. Valid template types are CMMI or Scrum or Agile."    
        }
        Write-Verbose "Using $vstsProjectTemplateType template. Id is: $templateTypeId"
        $vstsTeamProject.capabilities.processTemplate.templateTypeId = $templateTypeId

        if (
            (
                "Git".ToLower().Equals($vstsSourceControlType.ToLower()) -or 
                "Tfvc".ToLower().Equals($vstsSourceControlType.ToLower())
            ) -eq $false
        ) {
            throw "Template type $vstsSourceControlType is not a recognized template in VSTS. Valid types are Git or Tfvc."
        }
        $vstsTeamProject.capabilities.versioncontrol.sourceControlType = $vstsSourceControlType

        $body = $vstsTeamProject | ConvertTo-JSON

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
            $params = @{    
                ContentType = 'application/json'
                Headers     = @{
                    'Authorization' = "Basic $base64PatString"
                }
                body        = $body
                Method      = 'Post'    
                URI         = $vstsURL
            }

            Write-Verbose "Creating team project $vstsTeamProjectName"
            $authZResponse = Invoke-RestMethod @params
        }
        else {
            Write-Output "Team Project $vstsTeamProjectName state is $vstsProjectState"   
        }    
    
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
                Write-Output "Team Project $vstsTeamProjectName does not exist"   
                return
            }
            else {
                Write-Output "Team Project $vstsTeamProjectName state is $vstsProjectState"   
            }    
            if ($vstsProjectState -ne "wellFormed") {
                Write-Output "Waiting for project to be created..."
                Start-Sleep -s 5
            }
            else {
                Write-Output "Team Project $vstsTeamProjectName is ready for use"
            }     
        } while ($vstsProjectState -ne "wellFormed")    

    }
    catch {
        Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__
        Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
        Write-Verbose "Failed to create team projects $vstsTeamProjectName"
        throw
    }
}

function Set-GitRepository {
    param (
        [object]$resource
    )

    $vstsDevOpsSourcePath = "$PSScriptRoot\..\..\"

    $vstsAccountName = $resource.vstsAccountName
    $vstsTeamProjectName = $resource.vstsTeamProjectName

    $vstsUrl = "https://{0}.visualstudio.com/DefaultCollection/_git/{1}" -f $vstsAccountName, $vstsTeamProjectName

    $vstsFolderName = [System.IO.Path]::GetTempPath() 
    $vstsDevOpsDesitnationPath = $vstsFolderName + $vstsTeamProjectName
    $vstsDevBranch = $resource.vstsSourceControlDevBranch

    $vstsDevOpsSourceReadmePath = "{0}\Readme.md" -f $vstsDevOpsSourcePath
    Write-Verbose "DevOps Readme filepath : $vstsDevOpsSourceReadmePath"
    $vstsDevOpsDestinationReadmePath = $vstsFolderName + $vstsTeamProjectName + "\Readme.md"

    Push-Location
    try {
        Remove-Item $vstsDevOpsDesitnationPath -Recurse -Force -ErrorAction SilentlyContinue
        Set-Location -Path $vstsFolderName
        git clone $vstsUrl
        Set-Location -Path $vstsTeamProjectName
        git fetch origin
        git checkout -b master
        Copy-Item $vstsDevOpsSourceReadmePath $vstsDevOpsDestinationReadmePath -Force    
        Set-Location -Path $vstsDevOpsDesitnationPath
        git add .
        git commit -am "initial commit"
        git push --set-upstream origin master    
        git checkout -b $vstsDevBranch    
        Copy-Item -Path $vstsDevOpsSourcePath -Destination $vstsDevOpsDesitnationPath -Recurse -Force    
        Set-Location -Path $vstsDevOpsDesitnationPath
        # git add .
        # git commit -am "second commit"
        # git push --set-upstream origin $vstsDevBranch
    }
    finally {
        Pop-Location
        Remove-Item $vstsDevOpsDesitnationPath -Recurse -Force
    }
}

function Set-BuildDefinition {
    param
    (
        [object]$resource
    )
    $teamProjectFolder =  (Get-Item -Path $PSScriptRoot).Parent.FullName
    $cibuildDefinitionFile = "ci.build.definition.template.json"
    $nightlybuildDefinitionFile = "nightly.build.definition.template.json"   

    $vstsAccountName = $resource.vstsAccountName
    $vstsTeamProjectName = $resource.vstsTeamProjectName
    $vstsTeamProjectCIBuildDefinitionName = $resource.vstsTeamProjectCIBuildDefinitionName
    $vstsTeamProjectScheduledBuildDefinitionName = $resource.vstsTeamProjectScheduledBuildDefinitionName
    $vstsSourceControlDevBranch = $resource.vstsSourceControlDevBranch
    $vstsHostedAgentName = $resource.vstsHostedAgentName
    Write-Verbose "The default source control branch is $vstsSourceControlDevBranch"

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
        $vstsQueue = $authZResponse.value | Where-Object {$_.name -eq $vstsHostedAgentName}
        $vstsQueueId = $vstsQueue.id

        Write-Verbose "Hosted Queue Id for $vstsTeamProjectName is $vstsQueueId"    


        $vstsURL = "https://{0}.visualstudio.com/DefaultCollection/{1}/_apis/build/definitions?api-version=2.0" -f $vstsAccountName, $vstsTeamProjectName
        $params = @{    
            ContentType = 'application/json'
            Headers     = @{
                'Authorization' = "Basic $base64PatString"
            }
            body        = $body
            Method      = 'Get'    
            URI         = $vstsURL
        }
        Write-Verbose "Getting the build definitions for team project $vstsTeamProjectName"
        $authZResponse = Invoke-RestMethod @params
        $ciBuildDef = ($authZResponse.value | Where-Object {$_.name -eq $vstsTeamProjectCIBuildDefinitionName})
        $scheduledBuildDef = ($authZResponse.value | Where-Object {$_.name -eq $vstsTeamProjectScheduledBuildDefinitionName})

        $vstsTeamProjectUrl = "https://{0}.visualstudio.com/_git/{1}" -f $vstsAccountName, $vstsTeamProjectName
        $vstsDefaultBranch = "refs/heads/{0}" -f $vstsSourceControlDevBranch 
        $branchFilter = "+{0}" -f $vstsDefaultBranch
        $branchFilters += @($branchFilter)

        if ($ciBuildDef -eq $null) {
            $cibuildDefinitionFilePath = "{0}\templates\{1}" -f $teamProjectFolder, $cibuildDefinitionFile
            $buildDefinition = Get-Content -Path $cibuildDefinitionFilePath -Raw | ConvertFrom-Json
            $buildDefinition.name = $vstsTeamProjectCIBuildDefinitionName
            $buildDefinition.queue.id = $vstsQueueId
            $buildDefinition.triggers[0].branchFilters = $branchFilters
            $buildDefinition.repository.name = $vstsTeamProjectName
            $buildDefinition.repository.defaultBranch = $vstsDefaultBranch
            $buildDefinition.repository.url = $vstsTeamProjectUrl
            $body = $buildDefinition | ConvertTo-JSON -Depth 10

            $vstsURL = "https://{0}.visualstudio.com/DefaultCollection/{1}/_apis/build/definitions?api-version=2.0" -f $vstsAccountName, $vstsTeamProjectName
            $params = @{    
                ContentType = 'application/json'
                Headers     = @{
                    'Authorization' = "Basic $base64PatString"
                }
                body        = $body
                Method      = 'Post'    
                URI         = $vstsURL
            }
            Write-Verbose "Creating the CI build definitions for team project $vstsTeamProjectName"
            $authZResponse = Invoke-RestMethod @params
            $buildDefinitionId = $authZResponse.id
            Write-Verbose "CI Build Definition Id: $buildDefinitionId"
            Write-Output "CI Build Definition Id: $buildDefinitionId"
        }
        else {
            $buildDefinitionId = $ciBuildDef.id
            Write-Output "CI Build Definition exists with Id: $buildDefinitionId"
        }

        if ($scheduledBuildDef -eq $null) {
            $nightlybuildDefinitionFilePath = "{0}\templates\{1}" -f $teamProjectFolder, $nightlybuildDefinitionFile
            $buildDefinition = Get-Content -Path $nightlybuildDefinitionFilePath -Raw | ConvertFrom-Json
            $buildDefinition.name = $vstsTeamProjectScheduledBuildDefinitionName
            $buildDefinition.queue.id = $vstsQueueId
            $buildDefinition.triggers[0].schedules[0].branchFilters = $branchFilters
            $buildDefinition.repository.name = $vstsTeamProjectName
            $buildDefinition.repository.defaultBranch = $vstsDefaultBranch
            $buildDefinition.repository.url = $vstsTeamProjectUrl
            $body = $buildDefinition | ConvertTo-JSON -Depth 10
        
            $vstsURL = "https://{0}.visualstudio.com/DefaultCollection/{1}/_apis/build/definitions?api-version=2.0" -f $vstsAccountName, $vstsTeamProjectName
            $params = @{    
                ContentType = 'application/json'
                Headers     = @{
                    'Authorization' = "Basic $base64PatString"
                }
                body        = $body
                Method      = 'Post'    
                URI         = $vstsURL
            }
            Write-Verbose "Creating the Scheduled build definitions for team project $vstsTeamProjectName"
            $authZResponse = Invoke-RestMethod @params
            $buildDefinitionId = $authZResponse.id
            Write-Verbose "Scheduled Build Definition Id: $buildDefinitionId"
            Write-Output "Scheduled Build Definition Id: $buildDefinitionId"
        }
        else {
            $buildDefinitionId = $scheduledBuildDef.id
            Write-Output "Scheduled Build Definition exists with Id: $buildDefinitionId"
        }       
    }
    catch {
        Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
        Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
        throw
    }

}

function Set-ServiceEndPoint {
    param (
        [object]$resource
    )
    $vstsAccountName = $resource.vstsAccountName
    $vstsTeamProjectName = $resource.vstsTeamProjectName
    $vstsSourceControlDevBranch = $resource.vstsSourceControlDevBranch
    $vstsProjectARMServiceEndPointName = $resource.vstsProjectARMServiceEndPointName
    Write-Verbose "The default source control branch is $vstsSourceControlDevBranch"

    $subscriptionName = Get-ValueFromResourceRef -parameters $resource.parameters -type "subscriptionName"
    $subscriptionId = Get-ValueFromResourceRef -parameters $resource.parameters -type "subscriptionId"
    $tenantId = Get-ValueFromResourceRef -parameters $resource.parameters -type "tenantId"

    $serviceprincipalid = Get-ValueFromResourceRef -parameters $resource.parameters -type "applicationId"
    $keyVaultName = Get-ValueFromResourceRef -parameters $resource.parameters -type "keyvault"
    $secretName = Get-ValueFromResourceRef -parameters $resource.parameters -type "secretName"
    $clientsecret = (Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name $secretName).SecretValueText

    $patString = "{0}:{1}" -f "", $personalAccessToken
    $base64PatString = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes($patString))

    $teamProjectFolder =  (Get-Item -Path $PSScriptRoot).Parent.FullName
    $servicePrincipalDefinitionFile = "service.endpoint.template.json"    
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
        if ($vstsProjectARMServiceEndPoint -eq $null) {
            $vstsURL = "https://{0}.visualstudio.com/DefaultCollection/{1}/_apis/distributedtask/serviceendpoints?api-version=3.0-preview.1" -f $vstsAccountName, $vstsTeamProjectName    
            $serviceprincipalFilePath = "{0}\templates\{1}" -f $teamProjectFolder, $servicePrincipalDefinitionFile
            $servicePrincipalDefinition = Get-Content -Path $serviceprincipalFilePath -Raw | ConvertFrom-Json
            $servicePrincipalDefinition.name = $vstsProjectARMServiceEndPointName
            $servicePrincipalDefinition.data.subscriptionId = $subscriptionId
            $servicePrincipalDefinition.data.subscriptionName = $subscriptionName
            $servicePrincipalDefinition.authorization.parameters.serviceprincipalid = $serviceprincipalid
            $servicePrincipalDefinition.authorization.parameters.serviceprincipalkey = $clientsecret
            $servicePrincipalDefinition.authorization.parameters.tenantid = $tenantId
            $body = $servicePrincipalDefinition | ConvertTo-JSON -Depth 10

            $params = @{    
                ContentType = 'application/json'
                Headers     = @{
                    'Authorization' = "Basic $base64PatString"
                }
                body        = $body
                Method      = 'Post'    
                URI         = $vstsURL
            }
            Write-Verbose "Adding the service end point for $vstsTeamProjectName"
            $authZResponse = Invoke-RestMethod @params    
            Write-Output "The service end point $vstsProjectARMServiceEndPointName for $vstsTeamProjectName has been added"
        }
        else {
            Write-Output "The service end point $vstsProjectARMServiceEndPointName already exists for $vstsTeamProjectName"
        }
    }
    catch {
        Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
        Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
        throw
    }

}

function Set-ReleaseDefinition {
    param (
        [object]$resource
    )
    $teamProjectFolder =  (Get-Item -Path $PSScriptRoot).Parent.FullName
    $releaseDefinitionFile = "release.definition.template.json"
    
    $vstsAccountName = $resource.vstsAccountName
    $vstsTeamProjectName = $resource.vstsTeamProjectName
    $vstsSourceControlDevBranch = $resource.vstsSourceControlDevBranch

    $vstsTeamProjectCIBuildDefinitionName = $resource.vstsTeamProjectCIBuildDefinitionName
    $vstsTeamProjectCIReleaseDefinitionName = $resource.vstsTeamProjectCIReleaseDefinitionName

    $vstsTeamProjectScheduledBuildDefinitionName = $resource.vstsTeamProjectScheduledBuildDefinitionName
    $vstsTeamProjectScheduledReleaseDefinitionName = $resource.vstsTeamProjectScheduledReleaseDefinitionName

    $vstsHostedAgentName = $resource.vstsHostedAgentName
    function Add-Release {
        param
        (
            [String]$vstsTeamProjectBuildDefinitionName,
            [String]$vstsTeamProjectReleaseDefinitionName
        )
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
            $vstsQueue = $authZResponse.value | Where-Object {$_.name -eq $vstsHostedAgentName}
            $vstsQueueId = $vstsQueue.id
            Write-Verbose "Hosted Queue Id for $vstsTeamProjectName is $vstsQueueId"  

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
            $vstsBuildDefinition = $authZResponse.value | Where-Object {$_.name -eq $vstsTeamProjectBuildDefinitionName}
            $vstsTeamProjectId = $vstsBuildDefinition.project.id
            Write-Verbose "Project id for $vstsTeamProjectName is $vstsTeamProjectId"     
            $vstsTeamProjectBuildDefinitionId = $vstsBuildDefinition.id
            Write-Verbose "Build Definition id for build $vstsTeamProjectBuildDefinitionName is $buildDefinitionId"        

            $sourceId = "{0}:{1}" -f $vstsTeamProjectId, $vstsTeamProjectBuildDefinitionId

            Write-Verbose "PSScriptRoot is: $PSScriptRoot"
            $teamProjectFolder = (Get-Item -Path $PSScriptRoot).Parent.FullName
            Write-Verbose "Team Project Folder: $teamProjectFolder" 

            $vstsURL = "https://{0}.vsrm.visualstudio.com/DefaultCollection/{1}/_apis/release/definitions?api-version=3.0-preview.1" -f $vstsAccountName, $vstsTeamProjectName
            $params = @{    
                ContentType = 'application/json'
                Headers     = @{
                    'Authorization' = "Basic $base64PatString"
                }
                body        = $body
                Method      = 'Get'    
                URI         = $vstsURL
            }
            Write-Verbose "Getting release definition $vstsTeamProjectReleaseDefinitionName for team project $vstsTeamProjectName"
            $authZResponse = Invoke-RestMethod @params
            $releaseDef = ($authZResponse.value | Where-Object {$_.name -eq $vstsTeamProjectReleaseDefinitionName})
        
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
            $vstsProjectARMServiceEndPointName = $resource.vstsProjectARMServiceEndPointName
            $vstsProjectARMServiceEndPoint = $authZResponse.value | Where-Object {$_.name -eq $vstsProjectARMServiceEndPointName}
            $vstsTargetAzurePs = $resource.vstsTargetAzurePs
            $vstsCustomTargetAzurePs = $resource.vstsCustomTargetAzurePs
            $resourcesToDeploy = $resource.resourcesToDeploy
            if ($releaseDef -eq $null) {
                $releaseDefinitionFilePath = "{0}\Templates\{1}" -f $teamProjectFolder, $releaseDefinitionFile
                $releaseDefinition = Get-Content -Path $releaseDefinitionFilePath -Raw | ConvertFrom-Json
                $releaseDefinition.name = $vstsTeamProjectReleaseDefinitionName
                $releaseDefinition.environments[0].name = $vstsSourceControlDevBranch
                $releaseDefinition.environments[0].queueId = $vstsQueueId
                $releaseDefinition.environments[0].variables.parameterFile.value = $resourceParameterFile

                $scriptName = '$(System.DefaultWorkingDirectory)/{0}/Drop/DevOps/Scripts/15.Add-Resources.ps1' -f $vstsTeamProjectBuildDefinitionName
                $workingFolder = '$(System.DefaultWorkingDirectory)/{0}/Drop' -f $vstsTeamProjectBuildDefinitionName
                $arguments = '-parameterFile $(parameterFile) {0} -Verbose' -f $resourcesToDeploy
                $releaseDefinition.environments[0].deployStep.tasks[0].inputs.ConnectedServiceNameARM = $vstsProjectARMServiceEndPoint.id
                $releaseDefinition.environments[0].deployStep.tasks[0].inputs.ScriptPath = $scriptName
                $releaseDefinition.environments[0].deployStep.tasks[0].inputs.workingFolder = $workingFolder
                $releaseDefinition.environments[0].deployStep.tasks[0].inputs.ScriptArguments = $arguments
                $releaseDefinition.environments[0].deployStep.tasks[0].inputs.TargetAzurePs = $vstsTargetAzurePs
                $releaseDefinition.environments[0].deployStep.tasks[0].inputs.CustomTargetAzurePs = $vstsCustomTargetAzurePs

                $scriptName = '$(System.DefaultWorkingDirectory)/{0}/Drop/DevOps/Utilities/Remove-Resources.ps1' -f $vstsTeamProjectBuildDefinitionName
                $workingFolder = '$(System.DefaultWorkingDirectory)/{0}/Drop' -f $vstsTeamProjectBuildDefinitionName
                if ($removeResources) {
                    $arguments = '-parameterFile $(parameterFile) -SqlDW -DataFactory -Batch -ADLAnalytics'
                }       
                else {
                    $arguments = '-parameterFile $(parameterFile)'
                }

                $releaseDefinition.environments[0].deployStep.tasks[1].inputs.ConnectedServiceNameARM = $vstsProjectARMServiceEndPoint.id
                $releaseDefinition.environments[0].deployStep.tasks[1].inputs.ScriptPath = $scriptName
                $releaseDefinition.environments[0].deployStep.tasks[1].inputs.workingFolder = $workingFolder
                $releaseDefinition.environments[0].deployStep.tasks[1].inputs.ScriptArguments = $arguments
                $releaseDefinition.environments[0].deployStep.tasks[1].inputs.TargetAzurePs = $vstsTargetAzurePs
                $releaseDefinition.environments[0].deployStep.tasks[1].inputs.CustomTargetAzurePs = $vstsCustomTargetAzurePs

                $releaseDefinition.artifacts[0].sourceId = $sourceId
                $releaseDefinition.artifacts[0].alias = $vstsTeamProjectBuildDefinitionName
                $releaseDefinition.artifacts[0].definitionReference.definition.id = $vstsTeamProjectBuildDefinitionId.ToString()
                $releaseDefinition.artifacts[0].definitionReference.definition.name = $vstsTeamProjectBuildDefinitionName
                $releaseDefinition.artifacts[0].definitionReference.project.id = $vstsTeamProjectId
                $releaseDefinition.artifacts[0].definitionReference.project.name = $vstsTeamProjectName
                $releaseDefinition.triggers[0].artifactAlias = $vstsTeamProjectBuildDefinitionName        
                        
                $body = $releaseDefinition | ConvertTo-JSON -Depth 10

                $vstsURL = "https://{0}.vsrm.visualstudio.com/DefaultCollection/{1}/_apis/release/definitions?api-version=3.0-preview.1" -f $vstsAccountName, $vstsTeamProjectName
                $params = @{    
                    ContentType = 'application/json'
                    Headers     = @{
                        'Authorization' = "Basic $base64PatString"
                    }
                    body        = $body
                    Method      = 'Post'    
                    URI         = $vstsURL
                }
                Write-Verbose "Adding release definition $vstsTeamProjectReleaseDefinitionName for team project $vstsTeamProjectName"
                $authZResponse = Invoke-RestMethod @params
                $releaseDefinitionId = $authZResponse.id
                Write-Verbose "Release Definition Id: $releaseDefinitionId"
                Write-Output "Release Definition Id: $releaseDefinitionId"
            }
            else {
                Write-Verbose "Release Definition exists with Id: $releaseDefinitionId"
                Write-Output "Release Definition exists with Id: $releaseDefinitionId"
            }
        }
        catch {
            Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
            Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
            throw
        }
    }

    Add-Release -vstsTeamProjectBuildDefinitionName $vstsTeamProjectCIBuildDefinitionName -vstsTeamProjectReleaseDefinitionName $vstsTeamProjectCIReleaseDefinitionName
    Add-Release -vstsTeamProjectBuildDefinitionName $vstsTeamProjectScheduledBuildDefinitionName -vstsTeamProjectReleaseDefinitionName $vstsTeamProjectScheduledReleaseDefinitionName
}

function New-Build {
    param (
        [object]$resource
    )

    
    $jsonStr = @"
{
    "definition": {
        "id": 0
    }
}
"@

    $vstsAccountName = $resource.vstsAccountName
    $vstsTeamProjectName = $resource.vstsTeamProjectName
    $vstsTeamProjectCIBuildDefinitionName = $resource.vstsTeamProjectCIBuildDefinitionName

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
        $vstsTeamProjectBuildDefinitionId = ($authZResponse.value | Where-Object {$_.name -eq $vstsTeamProjectCIBuildDefinitionName}).id
        Write-Verbose "Build Definition id for build $vstsTeamProjectCIBuildDefinitionName is $vstsTeamProjectBuildDefinitionId"

        $buildQueue = $jsonStr | ConvertFrom-Json
        $buildQueue.definition.id = $vstsTeamProjectBuildDefinitionId
        $body = $buildQueue | ConvertTo-JSON -Depth 5

        $vstsURL = "https://{0}.visualstudio.com/DefaultCollection/{1}/_apis/build/builds?api-version=2.0" -f $vstsAccountName, $vstsTeamProjectName
        $params = @{    
            ContentType = 'application/json'
            Headers     = @{
                'Authorization' = "Basic $base64PatString"
            }
            body        = $body        
            Method      = 'Post'    
            URI         = $vstsURL
        }
        Write-Verbose "Queuing a new build for $vstsTeamProjectCIBuildDefinitionName"
        $authZResponse = Invoke-RestMethod @params
        Write-Verbose $authZResponse
        $buildId = $authZResponse.id
        Write-Output "Build Queued with id $buildId"
    }
    catch {
        Write-Host "StatusCode:" $_.Exception.Response.StatusCode.value__ 
        Write-Host "StatusDescription:" $_.Exception.Response.StatusDescription
        throw
    }
}

function Set-Resource {
    param (
        [object]$resource
    )
    Write-Verbose "Resource $resource"
    New-TeamProject -resource $resource
    Set-GitRepository -resource $resource
    Set-BuildDefinition -resource $resource
    Set-ServiceEndPoint -resource $resource
    Set-ReleaseDefinition -resource $resource
}

$parameterFileName = "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\Invoke-SetProcess.ps1" -projectsParameterFile $projectsParameterFile -parameterFileName $parameterFileName