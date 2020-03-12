param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function Set-Group {
    param(
        [string]$groupName,
        [bool]$createNew
    )
    $group = Get-AzureRmADGroup -DisplayName $groupName -ErrorAction SilentlyContinue
    if ($group -eq $null) {
        if ($createNew) {
            Write-Verbose "Group $groupName does not exist. Creating..."
            $group = New-AzureADGroup -Description "Group $groupName" -DisplayName $groupName -MailEnabled $false -MailNickName $groupName -SecurityEnabled $True
            $group = Get-AzureRmADGroup -DisplayName $groupName -ErrorAction SilentlyContinue
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
    return $group
}

function Set-Resource {
    param (
        [object]$resource
    )    
    $createNew = Get-CreateADGroupsStatus
    $group = Set-Group -groupName $resource.name -createNew $createNew
}

$parameterFileName = "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\Invoke-SetProcess.ps1" -projectsParameterFile $projectsParameterFile -parameterFileName $parameterFileName


