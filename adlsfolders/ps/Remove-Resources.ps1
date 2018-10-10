param
(
    [Parameter(Mandatory = $True, HelpMessage = 'The projects.parameters.json file.')]
    [String]$projectsParameterFile
)

function Remove-Resource {
    param(
        [object]$resource
    )
    $adlStoreName = $resource.adlStoreName
    $dataLakeStore = Get-AzureRmDataLakeStoreAccount | Where-Object {$_.Name -eq $adlStoreName}
    if ($dataLakeStore -eq $null) {
        Write-Verbose "Data Lake Store does not exist. Returning..."
        return
    }
    foreach ($obj in $resource.folders) {
        if (-not ("/".Equals($obj.folderName))) {
            Try {
                # Create the folder so long as it doesn't already exist.
                if ((Get-AzureRmDataLakeStoreItem -AccountName $adlStoreName -Path $obj.folderName -ErrorAction Ignore)) {
                    Write-Verbose "Remove folder $($obj.folderName)"
                    Remove-AzureRmDataLakeStoreItem -AccountName $adlStoreName -Path $obj.folderName -Recurse -Force
                }
                else{
                    Write-Verbose "Nothing to remove"
                }
            }
            Catch {
                Write-Error $_.Exception.Message
            }
        }
    }
}

$parameterFileName = "$((Get-Item -Path $PSScriptRoot).Parent.Name).parameters.json"
$commonPSFolder = (Get-Item -Path "$PSScriptRoot\..\..\common\ps").FullName
$null = & "$commonPSFolder\Invoke-RemoveProcess.ps1" `
    -projectsParameterFile $projectsParameterFile `
    -parameterFileName $parameterFileName
