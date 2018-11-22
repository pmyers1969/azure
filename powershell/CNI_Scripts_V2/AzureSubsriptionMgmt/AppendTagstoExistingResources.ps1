Function Merge-Hashtables {
    $Output = @{}
    ForEach ($Hashtable in ($Input + $Args)) {
        If ($Hashtable -is [Hashtable]) {
            ForEach ($Key in $Hashtable.Keys) {$Output.$Key = $Hashtable.$Key}
        }
    }
    $Output
}

##############################################################################################################
## Set Resource Group Tags for existing Resource Group                                                      ##
##############################################################################################################

$resourceGroup = "RG-SYD-Shared-Services"
$RG = Get-AzureRmResourceGroup -Name $resourceGroup

$Tag1 = "Shared"
$Tag2 = "Production"  # Production, Dev\Test\Train$Tag3 = "Shared" #backup, Networking, storage, VirtualMachines, WSCDC $Tag4 = ""
$Tag5 = ""#

$tags = @{ Tag1="$Tag1"; Tag2="$Tag2"; Tag3="$Tag3"; Tag4="$Tag4"; Tag5="$Tag5" }

Set-AzureRmResourceGroup -Name $resourceGroup -Tag $tags

## Set Policy for new resources added in

$policy = New-AzureRmPolicyDefinition -Name "$RGName-TagsDefinition" -Description "Policy to append resource Group Tags for $RGName" -Policy "{
    'if': {
    'field': 'tags',
    'exists': 'false'
    },
    'then': {
        'effect': 'append',
        'Details': [
            {
                'field': 'tags',
                'Value': {
                    'Tag1': ""$Tag1"",
                    'Tag2': ""$Tag2"",
                    'Tag3': ""$Tag3"", 
                    'Tag4': ""$Tag4"",
                    'Tag5': ""$Tag5""
                         }
                }
                ]
            }
    }"
    Start-Sleep -Seconds 10

New-AzureRmPolicyAssignment -Name "$RGname-TagsAssignment" -PolicyDefinition $policy -Scope $RG.ResourceId
#>


##############################################################################################################
## Set Tags for each resource in Resource Group                                                             ##
##############################################################################################################

$resources = Get-AzureRmResource | ? {$_.resourcegroupname -eq $resourceGroup} 

#$resources = $resources | ? {$_.resourcetype -notlike "Microsoft.Compute*"}
#$resources = $resources | ? {$_.resourcetype -like "Microsoft.Compute*"}
#$resources = $resources | ? {$_.resourcetype -like "Microsoft.Compute/virtualMachines"}

Foreach ($resource in $resources)
{
##Remove Resource from list ##
$resources = $resources | ? {$_.resourcename -ne $resource.Name}

#$RG = Get-AzureRmResourceGroup -Name $resource.ResourceGroupName
$tags = $null
$RGtags = $rg.tags
$Restags = $resource.tags
$tags = Merge-Hashtables $Restags $RGtags
Set-AzureRmResource -Resourceid $resource.ResourceId -Tag $tags -Force -Verbose
}
