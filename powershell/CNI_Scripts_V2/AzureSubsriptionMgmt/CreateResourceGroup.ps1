#Create a Resource Group

$RGName = "RG-AZSP000-Shared-PublicDNS"  #RG-<Mel/Syd>-<subdivision>-<purpose> 


#Add-AzureRmAccount

$subscription = "Spotless DR" # "VRL DEVTEST" "Edge Loyalty"

Set-AzureRmContext -SubscriptionName $subscription


$location = "AustraliaSouthEast" #AustraliaEast or AustraliaSouthEast

$Tag1 = "Spotless"
$Tag2 = "Corporate"$Tag3 = "IS"$Tag4 = "IS Infrastructure"
$Tag5 = "DNS"

$tags = @{ Tag1="$Tag1"; Tag2="$Tag2"; Tag3="$Tag3"; Tag4="$Tag4"; Tag5="$Tag5" }
$RG = New-AzureRmResourceGroup -Name $RGName -Location $location -Tag $tags

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


#SAMPLE code to remove using powershell 
<#
$assignments = Get-AzureRmPolicyAssignment | ? {$_.name -eq "$RGname-TagsAssignment"}
foreach ($assignment in $assignments)
{
Remove-AzureRmPolicyAssignment -Id $assignment.resourceID
}
#Get-AzureRmPolicyDefinition | ? {$_.name -like "RG*" } | Remove-AzureRmPolicyDefinition -Force
#>