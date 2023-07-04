<#
.SYNOPSIS
Use the graph API to get all discovered apps in your tenant and show the devices that have this app installed.

.DESCRIPTION
We use this graph call to get all discovered apps in your tenant:
https://graph.microsoft.com/beta/deviceManagement/detectedApps

More info about the graph call:
https://learn.microsoft.com/tr-tr/graph/api/intune-devices-detectedapp-list?view=graph-rest-beta



Coded by Vincent Verstraeten in 2023 for PatchMyPC
#>

#Region Authentication to Azure Application // Get token to authenticate to Azure AD
$authparams = @{
    ClientId     = 'd9eb62ce-b748-4a6f-8ccf-21f347cd1fd91'
    TenantId     = '33647b32-d6c6-43e9-a136-dcbaa396dc962'
    ClientSecret = (ConvertTo-SecureString 'O1b8Q~hIOqRoBmvqFW6oYLo.MJX3cq~Ke2uf9bq7' -AsPlainText -Force  )
}

$auth = Get-MsalToken @authParams


#Set Access token variable for use when making API calls
$AccessToken = $Auth.AccessToken
#endregion

#Region define arrays/variables
$allAps = @()
$alldevices = @()

#Apps that need to be extra filtered out and that cannot be patched by PatchMyPC or Scappman
$excludedAps = @(
    'Microsoft Intune Management Extension',
    'MicrosoftWindows.Client.WebExperience',
    'Microsoft Edge Update',
    'Microsoft Edge WebView2 Runtime',
    'Teams Machine-Wide Installer',
    'Microsoft Update Health Tools'                                     
)
#endregion

#Region Form the graph call
$URLupn = 'https://graph.microsoft.com/beta/deviceManagement/detectedApps?$filter=&$top=50' 


$paramApps = @{
    Headers     = @{
        "Content-Type"  = "application/json"
        "Authorization" = "Bearer $($AccessToken)"
    }
    Method      = "GET"
    URI         = $URLupn
    ErrorAction = "SilentlyContinue"
}
#endregion


#Region Get all apps with paging trough the graph call
$discoveredApps = Invoke-RestMethod @paramApps
$discoveredAppsNextLink = $discoveredApps.'@odata.nextLink'
$allAps += $discoveredApps.value
#paging 
while ($discoveredAppsNextLink) {
    $discoveredApps = Invoke-RestMethod -Uri $discoveredAppsNextLink -Headers $paramApps.Headers -Method Get
    $discoveredAppsNextLink = $discoveredApps.'@odata.nextLink'
    $allAps += $discoveredApps.value
}
#endregion


#Region Count apps we have discovered that are not Microsoft Store apps and not in excluded $exludedAps array

Write-Host "We discovered $(($allaps | Where-Object {$_.displayName -notlike 'Microsoft.*' -and $_.displayName -notin $excludedAps }).count) non Microsoft apps that can be managed"
#endregion

#Region Ask for list of all apps
Write-Host "You want a list of all apps? (y/n)"
$answer = Read-Host
if ($answer -eq "y") {
    write-host "Do you want to filter Microsoft apps? (y/n)"
    $answer = Read-Host
    if ($answer -eq "y") {
        $allApsNoMicrosoftStore = $allAps | Where-Object { $_.displayName -notlike 'Microsoft.*' -and $_.displayName -notin $excludedAps }
        $allApsNoMicrosoftStore | Sort-Object -Property deviceCount | Format-Table -AutoSize
        $listApps = $allApsNoMicrosoftStore
    }
    else {
        $allAps | Sort-Object -Property deviceCount | Format-Table -AutoSize
        $listApps = $allAps
    }
    
}
#endregion

#Region Ask for an app and show the devices that have this app installed
Write-Host "Do you want to see the devices that have a specific app installed? (y/n)"
$answer = Read-Host
if ($answer -eq "y") {
    Write-Host 'Please chose an app displayName:'
    $appDisplayname = Read-Host
    $app = $listApps | Where-Object { $_.displayName -eq $appDisplayname }
    $appID = $app.id
    $URL = "https://graph.microsoft.com/beta/deviceManagement/detectedApps('$appID')/managedDevices?$filter=&$top=20"
  

    $paramApps = @{
        Headers     = @{
            "Content-Type"  = "application/json"
            "Authorization" = "Bearer $($AccessToken)"
        }
        Method      = "GET"
        URI         = $URL
        ErrorAction = "SilentlyContinue"

    }

    #Get for a specific app all the devices
    $discoverDevices = Invoke-RestMethod @paramApps
    $discoverDevicesNextlink = $discoverdevices.'@odata.nextLink'

    #check this?????!!!
    $allDevices += $discoverDevices.value
    #need to page trough the results
    while ($discoverDevicesNextlink) {
        $discoverDevices = Invoke-RestMethod -Uri $discoverDevicesNextlink -Headers $paramApps.Headers -Method Get
        $discoverDevicesNextlink = $discoverDevices.'@odata.nextlink'
        $allDevices += $discoverDevices.value
    }

    foreach ($device in $allDevices) {
        $devicename = $device.deviceName
        write-host "The Application $appDisplayname is found in $devicename"
    }
}
else {
    Write-Host "Ok, bye!"
}
#endregion
