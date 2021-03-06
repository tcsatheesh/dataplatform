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


function Set-GroupMember {
    param (
        [string]$groupObjectId,
        [string]$userPrincipalName
    )
    $user = Get-AzureADUser -SearchString $userPrincipalName
    $membershipStatus = Get-AzureADGroupMember `
        -ObjectId $groupObjectId | Where {$_.UserPrincipalName -eq $userPrincipalName}
    if ($membershipStatus -eq $null) {
        if ($user -ne $null) {
            Add-AzureADGroupMember -ObjectId $groupObjectId -RefObjectId $user.ObjectId
            Write-Verbose "User added to the manager group"
        }
        else {
            throw "User does not exist"
        }
    }
    else {
        Write-Verbose "Member already exists in the group"
    }
}

function Set-Resource {
    param (
        [object]$resource
    )
    $adGroupObjectId = Get-ADGroupObjectId -adGroupType $resource.adgrouptyperef
    foreach ($membersupn in $resource.membersupn) {
        Write-Verbose "Adding user $membersupn to ad group $($resource.adgrouptyperef)"
        $upn = $membersupn
        if ($upn -eq "current") {
            $upn = Get-CurrentUserUpn
        }
        Set-GroupMember -groupObjectId $adGroupObjectId -userPrincipalName $upn
    }
}


$parameterFileName = "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\Invoke-SetProcess.ps1" -projectsParameterFile $projectsParameterFile -parameterFileName $parameterFileName


