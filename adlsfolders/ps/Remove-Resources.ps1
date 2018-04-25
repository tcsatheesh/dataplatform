param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function Remove-Resources {
    $adlStoreName = $parameters.parameters.resources.value.adlStoreName

    foreach ($obj in $parameters.parameters.resources.value.folders) {
        if (-not ("/".Equals($obj.folderName))) {
            Try {
                # Create the folder so long as it doesn't already exist.
                if ((Get-AzureRmDataLakeStoreItem -AccountName $adlStoreName -Path $obj.folderName -ErrorAction Ignore)) {
                    Remove-AzureRmDataLakeStoreItem -AccountName $adlStoreName -Path $obj.folderName -Recurse -Force
                }            
            }
            Catch {
                Write-Error $_.Exception.Message
            }
        }
    }
}

$parameterFileName = "adlsfolders.parameters.json"
$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
$null = & "$commonPSFolder\Invoke-RemoveProcess.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -parameterFileName $parameterFileName `
    -procToRun {Remove-Resources}
