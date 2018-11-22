Add-AzureRmAccount


$subscriptionName = 'VDHHS-ICS-L17-Prod'
$recoveryvault = 'RS-L17Backup'
$VMname = 'MELL17WEB02'
$RecstorageAccountName = 'sal17standshared02'
$storageAccountResourceGroup = "l17melstorage"
$VMresourceGroup = "l17melwebvm"


Set-AzureRmContext -SubscriptionName $subscriptionName
$Vault = Get-AzureRmRecoveryServicesVault  -Name $recoveryvault
Set-AzureRmRecoveryServicesVaultContext -Vault $Vault


$namedContainer = Get-AzureRmRecoveryServicesBackupContainer  -ContainerType AzureVM –Status Registered -FriendlyName $VMname
$backupitem = Get-AzureRmRecoveryServicesBackupItem –Container $namedContainer  –WorkloadType "AzureVM"

$startDate = (Get-Date).AddDays(-7)
$endDate = Get-Date
$rp = Get-AzureRmRecoveryServicesBackupRecoveryPoint -Item $backupitem -StartDate $startdate.ToUniversalTime() -EndDate $enddate.ToUniversalTime()
$rp = $rp[5]

$restorejob = Restore-AzureRmRecoveryServicesBackupItem -RecoveryPoint $rp[5] -StorageAccountName $RecstorageAccountName -StorageAccountResourceGroupName $storageAccountResourceGroup
$restorejob
Start-Sleep -Seconds 60
$restorejob = Get-AzureRmRecoveryServicesBackupJob -Job $restorejob
while ($restorejob.Status -eq "InProgress") 
{
Start-Sleep -Seconds 60
$restorejob = Get-AzureRmRecoveryServicesBackupJob -Job $restorejob
Write-Output "waiting for Restore to complete"
}

$details = Get-AzureRmRecoveryServicesBackupJobDetails $restorejob

#################################################################################################################
 $properties = $details.properties
 $storageAccountName = $properties["Target Storage Account Name"]
 $containerName = $properties["Config Blob Container Name"]
 $blobName = $properties["Config Blob Name"]

 Set-AzureRmCurrentStorageAccount -Name $storageaccountname -ResourceGroupName $storageAccountResourceGroup
 $destination_path = "C:\temp\vmconfig.json"
 Get-AzureStorageBlobContent -Container $containerName -Blob $blobName -Destination $destination_path
 $obj = ((Get-Content -Path $destination_path -Encoding Unicode)).TrimEnd([char]0x00) | ConvertFrom-Json

 $vm = New-AzureRmVMConfig -VMSize $obj.HardwareProfile.VirtualMachineSize -VMName "$VMname"

 Set-AzureRmVMOSDisk -VM $vm -Name "$VMname-C" -VhdUri $obj.StorageProfile.OSDisk.VirtualHardDisk.Uri -CreateOption “Attach”
 $vm.StorageProfile.OsDisk.OsType = $obj.StorageProfile.OSDisk.OperatingSystemType 
 foreach($dd in $obj.StorageProfile.DataDisks)
  {
  $vm = Add-AzureRmVMDataDisk -VM $vm -Name "datadisk1" -VhdUri $dd.VirtualHardDisk.Uri -DiskSizeInGB 127 -Lun $dd.Lun -CreateOption Attach
  }

 $nicName="mell17web02"
$NIC =  Get-AzureRmNetworkInterface -Name $nicName -ResourceGroupName $VMresourceGroup
 $vm=Add-AzureRmVMNetworkInterface -VM $vm -Id $nic.Id
 ## availability set
 $availset = Get-AzureRmAvailabilitySet -ResourceGroupName $VMresourceGroup -Name as-l17melweb 
 $VM.AvailabilitySetReference=$availset.Id


 New-AzureRmVM -ResourceGroupName $VMresourceGroup -Location AustraliaSouthEast -VM $vm