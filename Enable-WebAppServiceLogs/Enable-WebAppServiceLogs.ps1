function Add-IndexNumberToArray (
    [Parameter(Mandatory = $True)]
    [array]$array
) {
    for ($i = 0; $i -lt $array.Count; $i++) { 
        Add-Member -InputObject $array[$i] -Name "#" -Value ($i + 1) -MemberType NoteProperty 
    }
    $array
}

# Enable Web App Service Logs
function Enable-WebAppServiceLogs() {
    Add-AzureRmAccount

    [array]$SubscriptionArray = Add-IndexNumberToArray (Get-AzureRmSubscription) 
    [int]$SelectedSub = 0

    # use the current subscription if there is only one subscription available
    if ($SubscriptionArray.Count -eq 1) {
        $SelectedSub = 1
    }
    
    # Get SubscriptionID if one isn't provided
    while ($SelectedSub -gt $SubscriptionArray.Count -or $SelectedSub -lt 1) {
        Write-host "Please select a subscription from the list below"
        $SubscriptionArray | Select-Object "#", Id, Name | Format-Table
        try {
            $SelectedSub = Read-Host "Please enter a selection from 1 to $($SubscriptionArray.count)"
        }
        catch {
            Write-Warning -Message 'Invalid option, please try again.'
        }
    }

    # Select subscription
    Select-AzureRmSubscription -SubscriptionId $SubscriptionArray[$SelectedSub - 1].Id

    # Ask for the resource group.
    $resourceGroupName = Read-Host 'Resource Group name'

    # Ask for the storage account name
    $storageAccountName = Read-Host 'Storage account name'

    # Exit if resource group does not exists...
    $resourceGroup = Get-AzureRmResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
    if (!$resourceGroup) {
        Write-Verbose "$resourceGroup does not exists..."
        Exit 
    }

    # Create a new storage account.
    $storage = Get-AzureRmStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName -ErrorAction SilentlyContinue
    if (!$storage) {
        $storage = New-AzureRmStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName -Location $resourceGroup.Location -SkuName "Standard_ZRS"
    }

    # Create a container for the app logs 
    New-AzureStorageContainer -Context $storage.Context -Name "webapp-logs" -ErrorAction Ignore

    # Get a SAS token for the container
    $webSASToken = New-AzureStorageContainerSASToken -Context $storage.Context `
        -Name "webapp-logs" `
        -FullUri `
        -Permission rwdl `
        -StartTime (Get-Date).Date `
        -ExpiryTime (Get-Date).Date.AddYears(1)

    # Create a container for the http logs
    New-AzureStorageContainer -Context $storage.Context -Name "http-logs" -ErrorAction Ignore

    # Get a SAS token for the container
    $httpSASToken = New-AzureStorageContainerSASToken -Context $storage.Context `
        -Name "http-logs" `
        -FullUri `
        -Permission rwdl `
        -StartTime (Get-Date).Date `
        -ExpiryTime (Get-Date).Date.AddYears(1) 
    
    # Get all web app  in the resource group
    $resources = (Get-AzureRmResource).Where( {$_.ResourceType -eq "Microsoft.Web/sites" -and $_.ResourceGroupName -eq $resourceGroupName})

    # For each web app enable application and http logs 
    foreach ($resource in $resources) {
        # Property Object holding the log configuration.
        $propertiesObject = [ordered] @{
            'applicationLogs' = @{
                'azureBlobStorage' = @{
                    'level'           = 'Error' 
                    'sasUrl'          = [string]$webSASToken
                    'retentionInDays' = 30
                }
            }
            'httpLogs'        = @{
                'azureBlobStorage' = @{
                    'level'           = 'Error' 
                    'sasUrl'          = [string]$httpSASToken
                    'retentionInDays' = 30
                    'enabled'         = $true
                }
            }
        } 

        # Set the properties. Note that the resource type is: Microsoft.Web/sites/config and the resource name: [Web App Name]/logs
        Set-AzureRmResource `
            -PropertyObject $propertiesObject `
            -ResourceGroupName $resourceGroupName `
            -ResourceType Microsoft.Web/sites/config `
            -ResourceName "$($resource.ResourceName)/logs" -ApiVersion 2016-03-01 -Force          
    }
}

Enable-WebAppServiceLogs