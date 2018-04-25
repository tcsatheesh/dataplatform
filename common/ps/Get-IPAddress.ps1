$url = "https://api.ipify.org?format=json"
$response = Invoke-RestMethod -UseBasicParsing -Uri $url
return $response.ip