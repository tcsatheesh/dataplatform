param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function Get-CreateADGroupsStatus {
    $createADGroups = "createADGroups"
    $parameterFileName = "projects.parameters.json"
    $parameters = Get-ResourceParameters -parameterFileName $parameterFileName
    $resource = $parameters.parameters.resources.value | Where-Object {$_.type -eq $createADGroups}
    $createNew = $resource.status
    Write-Verbose "Create status for AD Groups $createNew"
    return $createNew
}

function Set-Group {
    param(
        [string]$groupName,
        [bool]$createNew
    )
    $group = Get-AzureADGroup -SearchString $groupName -ErrorAction SilentlyContinue
    if ($group -eq $null) {
        if ($createNew) {
            Write-Verbose "Group $groupName does not exist. Creating..."
            $group = New-AzureADGroup -Description "Group $groupName" -DisplayName $groupName -MailEnabled $false -MailNickName $groupName -SecurityEnabled $True
            $group = Get-AzureADGroup -SearchString $groupName -ErrorAction SilentlyContinue
            Write-Verbose "Group $groupName created."
        }
        else {
            throw "AD Group $groupName does not exist."
        }
    }
    else {
        Write-Verbose "Group $groupName exists."
    }
    $groupId = $group.ObjectId
    Write-Verbose "Group id for $groupName is $groupId"
    return $groupId
}

function Set-Resource {
    param (
        [object]$resource
    )    
    $createNew = Get-CreateADGroupsStatus
    $resource.id = Set-Group -groupName $resource.name -createNew $createNew
}

$parameterFileName = "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\Invoke-SetProcess.ps1" -projectsParameterFile $projectsParameterFile -parameterFileName $parameterFileName


