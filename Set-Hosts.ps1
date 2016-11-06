[CmdletBinding()]
param([string]$servers, [string]$domain)
$cert = New-SelfSignedCertificate -Subject "*.$domain" -DnsName "*.$domain",$domain -CertStoreLocation Cert:\LocalMachine\My
$certHash = $cert.GetCertHash()
Set-WebConfigurationProperty -PSPath 'MACHINE/WEBROOT/APPHOST' -Name 'enabled' -Filter 'system.webServer/proxy' -Value 'True'
$sm = Get-IISServerManager
$serverjson = $servers | ConvertFrom-Json
foreach($server in $serverjson)
{
    $bindingurl = "$($server.externalHostname).$domain"
    $sm.Sites['Default Web Site'].Bindings.Add("*:443:$bindingurl", $certHash, 'My', '1')
    
    $site = "iis:\sites\Default Web Site"
    $filter = "system.webServer/rewrite/rules"
    $match = @{
        url = "(.*)"
        ignoreCase = $true
    }
    $conditions = @{
        input = "{HTTP_HOST}"
        matchType = "Pattern"
        pattern = $server.containerHostname
        ignoreCase = $true
    }
    $action = @{
        type = "Rewrite"
        url = "http://$($server.containerHostname)/$($server.appPath)/{R:1}"
        appendQueryString = $true
    }
    $ruleprops = @{
        name = $server.containerHostname
        enabled = $true
        patternSyntax = "ECMAScript"
        stopProcessing = $true
        match = $match
        action = $action
    }
    Add-WebConfigurationProperty -PSPath $site -Filter $filter -Name "." -Value $ruleprops -Verbose
    $conditionsfilter = "$filter/rule[@name='$($server.containerHostname)']/conditions"
    Set-WebConfigurationProperty -PSPath $site -Name "Collection" -Filter $conditionsfilter -Value $conditions -Verbose
}
$sm.CommitChanges()
Stop-Website -Name 'Default Web Site'
Start-Website -Name 'Default Web Site'

Start-Process C:\ServiceMonitor.exe -ArgumentList "w3svc" -Wait