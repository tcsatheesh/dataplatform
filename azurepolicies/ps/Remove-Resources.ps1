param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function Remove-Resource {
    param(
        [object]$resource
    )

    $subscriptionId = Get-SubscriptionId
    $scope = "/subscriptions/$subscriptionId"

    $assignments = $resource.parameters | Where-Object {$_.type -eq "assignment"}
    foreach ($assignment in $assignments) {
        Write-Verbose "Removing assignment $($assignment.name)"
        $null = Remove-AzureRmPolicyAssignment -Name $assignment.name -Scope $scope
        Write-Verbose "Removed assignment $($assignment.name)"
    }

    $policydefintion = $resource.parameters | Where-Object {$_.type -eq "policydefinition"}
    $name = $policydefintion.name
    $displayName = $policydefintion.displayName
    $description = $policydefintion.description
    $subscriptionId = Get-SubscriptionId
    Write-Verbose "Policy definition is $name "
    if ($resource.subtype -eq "policyset") {
        $rdef = Get-AzureRmPolicySetDefinition -Name $name -ErrorAction SilentlyContinue
        if ($rdef -eq $null) {
            Write-Verbose "Policy set definition $name does not exist"
        }
        else {
            Write-Verbose "Policy set definition $name exists. Removing..."
            $null = Remove-AzureRmPolicySetDefinition -Name $name -Force
            Write-Verbose "Policy set definition $name removed."
        }
    } else {
        try{
            $rdef = Get-AzureRmPolicyDefinition -Name $name -ErrorAction SilentlyContinue
        }catch{}
        if ($rdef -eq $null) {
            Write-Verbose "Policy definition $name does not exist"
        }
        else {
            Write-Verbose "Policy definition $name exists. Removing..."
            $null = Remove-AzureRmPolicyDefinition -Name $name -Force
            Write-Verbose "Policy definition $name removed."
        }
    }
}

$parameterFileName = "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
& "$commonPSFolder\Invoke-RemoveProcess.ps1" -projectsParameterFile $projectsParameterFile -parameterFileName $parameterFileName
