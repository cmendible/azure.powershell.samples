Param 
(
    [Parameter(Mandatory = $true)][string]$resourceGroupName,
    [Parameter(Mandatory = $true)][string]$analysisServicesName,
    [Parameter(Mandatory = $true)][string]$firewallRuleName,
    [Parameter(Mandatory = $true)][string]$rangeStart,
    [Parameter(Mandatory = $true)][string]$rangeEnd)

function Add-AnalysisServicesFirewallRule($props, $firewallRuleName, $rangeStart, $rangeEnd) {
    # Check if the rule exists
    $existingRules = $props.ipV4FirewallSettings.firewallRules | `
        Where-Object {$_.firewallRuleName -eq $firewallRuleName}

    # Add the rule if needed
    if ($existingRules -eq $null) {
        # Create the rule object
        $ruleProperties = [ordered]@{
            "firewallRuleName" = $firewallRuleName;
            "rangeStart"       = $rangeStart;
            "rangeEnd"         = $rangeEnd;
        }
        $rule = New-Object -TypeName PSObject
        $rule | Add-Member -NotePropertyMembers $ruleProperties

        # Add the rule 
        $rules = [System.Collections.ArrayList]$props.ipV4FirewallSettings.firewallRules
        $index = $rules.Add($rule)
        $props.ipV4FirewallSettings.firewallRules = $rules
    }
}

function Add-FirewallSectionAndEnablePowerBIAccess($props) {
    # Check if ipV4FirewallSettings property exists
    $ipV4FirewallSettingsProperty = $props | Get-Member -Name "ipV4FirewallSettings"
    if (!$ipV4FirewallSettingsProperty) {
        # Create the ipV4FirewallSettings property and enable the PowerBI Service
        $props | Add-Member @{ipV4FirewallSettings = [ordered] @{ 
                "firewallRules"        = @()
                "enablePowerBIService" = $true
            }
        }
    }
}

# Get the AnalysisServices resource properties
$resource = Get-AzureRmResource `
    -ResourceGroupName $resourceGroupName `
    -ResourceType "Microsoft.AnalysisServices/servers" `
    -ResourceName $analysisServicesName

$props = $resource.Properties

Add-FirewallSectionAndEnablePowerBIAccess $props

Add-AnalysisServicesFirewallRule $props $firewallRuleName $rangeStart $rangeEnd

Set-AzureRmResource `
    -PropertyObject $props `
    -ResourceGroupName $resourceGroupName `
    -ResourceType "Microsoft.AnalysisServices/servers" `
    -ResourceName $analysisServicesName `
    -Force