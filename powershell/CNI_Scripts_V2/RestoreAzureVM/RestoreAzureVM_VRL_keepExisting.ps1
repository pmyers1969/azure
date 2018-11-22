<# Notess 
- The origional VM is kept running and a new VM suffixed with Restored is created 
- Not tested for a VM that is a member of an Azure Load Balancer 
- Creates a file "C:\temp\vmconfig.json" during the process
- Azure Powershell is required to be installed on the system running the script.
#>

####################
# Login to Azure with VRL -a account
####################
Add-AzureRmAccount

####################
# Update the following Variables 
####################


$subscriptionName = 'VRL'
$recoveryvault = 'RSV-AZMEL-SAPPROD-01'  # RSV-AZMEL-SAPPROD-01 # RSV-AZSYD-SAPPROD-01
$VMname = 'AZSAPAPP52'
$VMstorageAccountName = 'savrlazmelstdlocsapprd01'
$storageAccountResourceGroup = "RG-SharedServices-SAPPROD-DR"
$VMresourceGroup = "RG-SharedServices-SAPPROD-DR"
$nicName= "AZSAPAPP52-nic1"
$availabiltyset = "AS-AZMEL-SAPAPP01"
#networkInformation
$VNetName = "VN-Mel"
$VnetResourceGroup = "RG-VNMEL"
$subnetName = "Corp_SAP"

#### 
$RestoredVMname= "$VMname-Restored"
$RestoredNicName= "$nicName-Restored"




# Script retrieves the Azure recoery vault and sets the contect for execution
$ErrorActionPreference = "stop" 
Set-AzureRmContext -SubscriptionName $subscriptionName
$Vault = Get-AzureRmRecoveryServicesVault  -Name $recoveryvault
Set-AzureRmRecoveryServicesVaultContext -Vault $Vault
$location = $vault.location
$namedContainer = Get-AzureRmRecoveryServicesBackupContainer  -ContainerType AzureVM –Status Registered -FriendlyName $VMname
$backupitem = Get-AzureRmRecoveryServicesBackupItem –Container $namedContainer  –WorkloadType "AzureVM"

######################
# Retrieve the last 29 days worth of restore points 
###################### 
$startDate = (Get-Date).AddDays(-29)
$endDate = Get-Date
$recoverypoints = Get-AzureRmRecoveryServicesBackupRecoveryPoint -Item $backupitem -StartDate $startdate.ToUniversalTime() -EndDate $enddate.ToUniversalTime()
$rp = $recoverypoints | Out-GridView -PassThru
Write-Host -ForegroundColor Green "Please select recovery point to restore"

$restorejob = Restore-AzureRmRecoveryServicesBackupItem -RecoveryPoint $rp -StorageAccountName $VMstorageAccountName -StorageAccountResourceGroupName $storageAccountResourceGroup
$restorejob
Start-Sleep -Seconds 60
$restorejob = Get-AzureRmRecoveryServicesBackupJob -Job $restorejob
while ($restorejob.Status -eq "InProgress") 
{
Start-Sleep -Seconds 60
$restorejob = Get-AzureRmRecoveryServicesBackupJob -Job $restorejob
Write-Host -ForegroundColor Green "waiting for Restore to complete"
}
Write-Host -ForegroundColor Green "Restore of disks completed"
$details = Get-AzureRmRecoveryServicesBackupJobDetails $restorejob


######################
# Remove old VM and build Restore VM
###################### 

 $properties = $details.properties
 $storageAccountName = $properties["Target Storage Account Name"]
 $containerName = $properties["Config Blob Container Name"]
 $blobName = $properties["Config Blob Name"]

 Set-AzureRmCurrentStorageAccount -Name $storageaccountname -ResourceGroupName $storageAccountResourceGroup
 $destination_path = "C:\temp\vmconfig.json"
 Get-AzureStorageBlobContent -Container $containerName -Blob $blobName -Destination $destination_path
 $obj = ((Get-Content -Path $destination_path -Encoding Unicode)).TrimEnd([char]0x00) | ConvertFrom-Json

 $vm = New-AzureRmVMConfig -VMSize $obj.HardwareProfile.VirtualMachineSize -VMName "$RestoredVMname"

 Set-AzureRmVMOSDisk -VM $vm -Name "$RestoredVMname-C" -VhdUri $obj.StorageProfile.OSDisk.VirtualHardDisk.Uri -CreateOption “Attach”
 $vm.StorageProfile.OsDisk.OsType = $obj.StorageProfile.OSDisk.OperatingSystemType 
 $count = 1
 foreach($dd in $obj.StorageProfile.DataDisks)
  {
  $vm = Add-AzureRmVMDataDisk -VM $vm -Name "datadisk-$count" -VhdUri $dd.VirtualHardDisk.Uri -DiskSizeInGB 127 -Lun $dd.Lun -CreateOption Attach
  $count++
  }
 
    
;
 
     $nicName=$RestoredNicName
     $vnet = Get-AzureRmVirtualNetwork -Name $VNetName -ResourceGroupName $VnetResourceGroup
     $subnet = Get-AzureRmVirtualNetworkSubnetConfig -Name $subnetName -VirtualNetwork $vnet
     $nic = New-AzureRmNetworkInterface -Name $RestoredNicName -ResourceGroupName $VMresourceGroup -Location $location -SubnetId $Subnet.Id
     $vm=Add-AzureRmVMNetworkInterface -VM $vm -Id $nic.Id



 $vm=Add-AzureRmVMNetworkInterface -VM $vm -Id $nic.Id
 ## availability set
 $availset = Get-AzureRmAvailabilitySet -ResourceGroupName $VMresourceGroup -Name $availabiltyset 
 $VM.AvailabilitySetReference=$availset.Id

 New-AzureRmVM -ResourceGroupName $VMresourceGroup -Location $location -VM $vm