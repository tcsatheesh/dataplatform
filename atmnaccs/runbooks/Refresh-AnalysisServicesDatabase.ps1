$Credential = Get-AutomationPSCredential -Name "ServicePrincipal"

$TenantId = Get-AutomationVariable -Name "TenantId"
$databaseName = Get-AutomationVariable -Name "AnalysisServicesDatabaseName"
$analysisServer = Get-AutomationVariable -Name "AnalysisServicesServer"
$analysisSeverRolloutEnvironment = Get-AutomationVariable -Name "AnalysisServicesRolloutEnvironment"
$refreshType = Get-AutomationVariable -Name "DatabaseRefreshType"

Add-AzureAnalysisServicesAccount -Credential $Credential -ServicePrincipal -TenantId $TenantId -RolloutEnvironment $analysisSeverRolloutEnvironment
Invoke-ProcessASDatabase -DatabaseName $databaseName -RefreshType $refreshType -Server $analysisServer