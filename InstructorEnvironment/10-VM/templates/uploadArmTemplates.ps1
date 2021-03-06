#Upload linked ARM templates to storage account, create SAS token and save it to JSON settings file
#Written by Fabien Gilbert, AIS, in June of 2019
$currentFolder = Split-Path $script:MyInvocation.MyCommand.Path
$TemplateSettingsPath = ($currentFolder + "\uploadArmTemplates_Settings.json")
$customScriptName = "CustomScriptDiskConfig.ps1"
$customScriptPath = ($currentFolder.Replace("templates","customScripts") + "\" + $customScriptName)
$TemplateSettings = Get-Content -Path $TemplateSettingsPath | ConvertFrom-Json
if(!(Get-AzContext).Subscription.Name -ne $TemplateSettings.StorageAccountSubscription){Set-AzContext -SubscriptionName $TemplateSettings.StorageAccountSubscription}
$StorObj = Get-AzStorageAccount -ResourceGroupName $TemplateSettings.StorageAccountResourceGroup -Name $TemplateSettings.StorageAccountName
$SASStartTime = Get-Date
$SASEndTime = $SASStartTime.AddYears(3)
#Create SAS Token if it doesn't exist
if(!($TemplateSettings.StorageAccountContainerUri -and $TemplateSettings.StorageAccountContainerSasToken)){
    #Create container SAS token
    $CST = New-AzStorageContainerSASToken -Context $StorObj.Context -Name $TemplateSettings.StorageAccountContainer -Permission r -StartTime $SASStartTime -ExpiryTime $SASEndTime
    #Get container uri
    $cUri = Get-AzStorageContainer -Context $StorObj.Context -Name $TemplateSettings.StorageAccountContainer
    Add-Member -InputObject $TemplateSettings -Name "StorageAccountContainerUri" -MemberType NoteProperty -Value $cUri.CloudBlobContainer.Uri.AbsoluteUri -Force
    Add-Member -InputObject $TemplateSettings -Name "StorageAccountContainerSasToken" -MemberType NoteProperty -Value $CST -Force
}
foreach($T in $TemplateSettings.List){    
    $B = $null;$templatePath=$null
    $templatePath = ($currentFolder + "\" + $T.Name)
    $B = Get-AzStorageBlob -Context $StorObj.Context -Container $TemplateSettings.StorageAccountContainer -Blob $T.Name -ErrorAction:SilentlyContinue
    $TemplateFile = Get-ChildItem -Path $templatePath
    if($TemplateFile.LastWriteTimeUtc -gt $B.LastModified.UtcDateTime)
    {
        Set-AzStorageBlobContent -Context $StorObj.Context -Container $TemplateSettings.StorageAccountContainer -Blob $T.Name -File $templatePath        
    }
}
$TemplateSettings | ConvertTo-Json | Out-File -FilePath $TemplateSettingsPath
#Upload DiskConfig CustomScript
$customScriptBlob = Get-AzStorageBlob -Context $StorObj.Context -Container $TemplateSettings.StorageAccountContainer -Blob $customScriptName -ErrorAction:SilentlyContinue
$customScripFile = Get-ChildItem -Path $customScriptPath
if($customScripFile.LastWriteTimeUtc -gt $customScriptBlob.LastModified.UtcDateTime)
{
    Set-AzStorageBlobContent -Context $StorObj.Context -Container $TemplateSettings.StorageAccountContainer -Blob $customScriptName -File $customScriptPath       
}