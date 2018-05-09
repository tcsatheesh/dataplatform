param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile,

    [Parameter(Mandatory = $False, HelpMessage = 'The duration of sign in activity.')]
    [int]$numberOfDays = 7
)

$oauth = & "$PSScriptRoot\Get-AccessToken.ps1" -projectsParameterFile $projectsParameterFile
$parameters = & "$PSScriptRoot\Get-ParameterSet.ps1" -projectsParameterFile $projectsParameterFile
$tenant = $parameters.projects | Where-Object {$_.type -eq "tenant"}
$tenantName = $tenant.name

if ($oauth.access_token -ne $null) {
$headerParams = @{'Authorization'="$($oauth.token_type) $($oauth.access_token)"}


$7daysago = "{0:s}" -f (get-date).AddDays(-$numberOfDays) + "Z"
# or, AddMinutes(-5)
# Write-Output $7daysago
$url = "https://graph.windows.net/$tenantName/activities/signinEvents?api-version=beta&`$filter=signinDateTime ge $7daysago"

$i=0

Do{
    Write-Output "Fetching data using Uri: $url"
    $myReport = (Invoke-WebRequest -UseBasicParsing -Headers $headerParams -Uri $url)
    Write-Output "Save the output to a file SigninActivities$i.json"
    Write-Output "---------------------------------------------"
    $myReport.Content | Out-File -FilePath SigninActivities$i.json -Force
    $url = ($myReport.Content | ConvertFrom-Json).'@odata.nextLink'
    $i = $i+1
} while($url -ne $null)

} else {

    Write-Host "ERROR: No Access Token"
}