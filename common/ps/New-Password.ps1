param
( 
    [int] $numchars = 22,
    [string]$chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789@#"
)
do {
    $bytes = new-object "System.Byte[]" $numchars
    $rnd = new-object System.Security.Cryptography.RNGCryptoServiceProvider
    $rnd.GetBytes($bytes)
    $result = ""
    $repeat = $false
    for ( $i = 0; $i -lt $numchars; $i++ ) {
        $result += $chars[ $bytes[$i] % $chars.Length ]   
    }
    if (-Not $result.Contains("@") -or -Not $result.Contains("#")) {
        $repeat = $true;
    }
        if (-Not ($result -match "[0-9]")) {
        $repeat = $true;
    }
} while ($repeat)

$secret = ConvertTo-SecureString -AsPlainText $result -Force
$props = @{
    securePassword = $secret
    passowrd = $result
}

return $props