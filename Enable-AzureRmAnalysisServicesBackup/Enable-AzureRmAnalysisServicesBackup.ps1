Param 
(
    [Parameter(Mandatory = $true)][string]$resourceGroupName,
    [Parameter(Mandatory = $true)][string]$analysisServicesName,
    [Parameter(Mandatory = $true)][string]$storageAccountName,
    [Parameter(Mandatory = $true)][string]$containerName)

function Add-AnalysisServicesBackupBlobContainer($props, $resourceGroupName, $storageAccountName, $containerName) {
    # Get storage account keys.
    $keys = Get-AzureRmStorageAccountKey `
        -StorageAccountName $storageAccountName `
        -ResourceGroupName $resourceGroupName

    # Use first key.
    $key = $keys[0].Value

    # Create an Azure Storage Context for the storage account. 
    $context = New-AzureStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $key

    # Create a 2 Years SAS Token
    $starTime = (Get-Date).AddMinutes(-5)
    $sasToken = New-AzureStorageContainerSASToken `
        -Name $containerName `
        -Context $context `
        -ExpiryTime $starTime.AddYears(2) `
        -Permission rwdlac `
        -Protocol HttpsOnly `
        -StartTime $starTime
        
    # Create the Container Uri
    $blobContainerUri = "https://$($storageAccountName).blob.core.windows.net/$($containerName)$($sasToken)"

    # Check the Analysis Server to see if the backupBlobContainerUri property exists. 
    $backupBlobContainerUriProperty = $props | Get-Member -Name "backupBlobContainerUri"
    if (!$backupBlobContainerUriProperty) {
        # Add the property to the object. 
        $props | Add-Member @{backupBlobContainerUri = ""} 
    }

    # Set the container Uri
    $props.backupBlobContainerUri = $blobContainerUri
}

# Get the Analysis Services resource properties.
$resource = Get-AzureRmResource `
    -ResourceGroupName $resourceGroupName `
    -ResourceType "Microsoft.AnalysisServices/servers" `
    -ResourceName $analysisServicesName

$props = $resource.Properties

# Modify the backupBlobContainerUri.
Add-AnalysisServicesBackupBlobContainer $props $resourceGroupName $storageAccountName $containerName

# Save the properties. 
Set-AzureRmResource `
    -PropertyObject $props `
    -ResourceGroupName $resourceGroupName `
    -ResourceType "Microsoft.AnalysisServices/servers" `
    -ResourceName $analysisServicesName `
    -Force