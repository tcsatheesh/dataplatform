param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

$parameterFileName = "projects.parameters.json"
$parameters = & "$PSScriptRoot\Get-ResourceParameters.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -parameterFileName $parameterFileName

$subscriptionId = ($parameters.parameters.resources.value | Where-Object {$_.type -eq "subscription"}).id
$sub = Select-AzureRmSubscription -SubscriptionId $subscriptionId
