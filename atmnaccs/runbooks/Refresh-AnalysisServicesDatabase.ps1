$TenantId = Get-AutomationVariable -Name "TenantId"
$Credential = Get-AutomationPSCredential -Name "ServicePrincipal"
$databaseName = Get-AutomationVariable -Name "AnalysisServicesDatabaseName"
$analysisServer = Get-AutomationVariable -Name "AnalysisServicesServer"
$analysisSeverRolloutEnvironment = Get-AutomationVariable -Name "AnalysisServerRolloutEnvironment"
$refreshType = Get-AzureAutomationVariable -Name "DatabaseRefreshType"

Add-AzureAnalysisServicesAccount -Credential $Credential -ServicePrincipal -TenantId $TenantId -RolloutEnvironment $analysisSeverRolloutEnvironment
Invoke-ProcessASDatabase -DatabaseName $databaseName -RefreshType $refreshType -Server $analysisServer