param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)


function Get-ADGroupObjectId {
    param (
        [string]$adGroupType
    )
    $parameterFileName = "adgroups.parameters.json"
    $parameters = Get-ResourceParameters -parameterFileName $parameterFileName
    $adGroup = $parameters.parameters.resources.value | Where-Object {$_.type -eq $adGroupType}
    return $adGroup.id
}

function Get-CurrentUserUpn {
    $parameterFileName = "projects.parameters.json"
    $parameters = Get-ResourceParameters -parameterFileName $parameterFileName

    $subscriptionId = ($parameters.parameters.resources.value | Where-Object {$_.type -eq "subscription"}).id
    $sub = Select-AzureRmSubscription -SubscriptionId $subscriptionId
    $upn = $sub.Account.Id
    Write-Verbose "Current user upn is : $upn"
    return $upn
}

function Remove-Resource {
    param (
        [string]$groupObjectId,
        [string]$userPrincipalName
    )
    $user = Get-AzureADUser -SearchString $userPrincipalName
    $membershipStatus = Get-AzureADGroupMember `
        -ObjectId $groupObjectId | Where {$_.UserPrincipalName -eq $userPrincipalName}
    if ($membershipStatus -ne $null) {
        if ($user -ne $null) {
            Write-Verbose "Removing Azure AD Group Member"
            $application = Remove-AzureADGroupMember -ObjectId $groupObjectId -MemberId $user.ObjectId
            Write-Verbose "Removed Azure AD Group Member"
        }
        else {
            throw "User does not exist"
        }
    }
    else {
        Write-Verbose "Member does not exist in the group"
    }
}


function Remove-Resources {
    foreach ($resource in $parameters.parameters.resources.value) {
        $adGroupObjectId = Get-ADGroupObjectId -adGroupType $resource.adgrouptyperef
        foreach ($membersupn in $resource.membersupn) {
            Write-Verbose "Removing user $membersupn to ad group $($resource.adgrouptyperef)"
            $upn = $membersupn
            if ($upn -eq "current") {
                $upn = Get-CurrentUserUpn
            }
            Remove-Resource -groupObjectId $adGroupObjectId -userPrincipalName $upn
        }
    }
}

$parameterFileName = "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
$null = & "$commonPSFolder\Invoke-RemoveProcess.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -parameterFileName $parameterFileName `
    -procToRun {Remove-Resources}