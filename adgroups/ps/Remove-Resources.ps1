param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function Remove-Group {
    param (
        [string]$groupName
    )
    Write-Verbose "Searching Azure AD Group $groupName"
    $group = Get-AzureADGroup -SearchString $groupName -ErrorAction SilentlyContinue
    if ($group -ne $null) {
        Write-Verbose "Removing Azure AD Group $groupName"
        try {
            $application = Remove-AzureADGroup -ObjectId $group.ObjectId
            Write-Verbose "Removed Azure AD Group $groupName"
        }
        catch {
            Write-Verbose "Did not remove Azure AD Group $groupName"
        } 
    }
    else {
        Write-Verbose "Azure AD Group does not exist"
    }
}

function Remove-Resource {
    param (
        [object]$resource
    )
    Remove-Group -groupName $resource.name
}

$parameterFileName = "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
$null = & "$commonPSFolder\Invoke-RemoveProcess.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -parameterFileName $parameterFileName