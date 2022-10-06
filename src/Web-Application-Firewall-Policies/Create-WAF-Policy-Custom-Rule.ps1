[CmdletBinding()]
param (
    [Parameter(Mandatory)][string] $WafPolicyName, 
    [Parameter(Mandatory)][string] $WafPolicyCustomRuleName,
    [Parameter(Mandatory)][string] $WafPolicyResourceGroupName, 
    [Parameter(Mandatory)][string][ValidateSet("RemoteAddr", "RequestMethod", "QueryString", "PostArgs", "RequestUri", "RequestHeader", "RequestBody", "Cookies", "SocketAddr")] $WafPolicyCustomRuleConditionMatchVariable,
    [Parameter(Mandatory)][string][ValidateSet("Any", "IPMatch", "GeoMatch", "Equal", "Contains", "LessThan", "GreaterThan", "LessThanOrEqual", "GreaterThanOrEqual", "BeginsWith", "EndsWith", "RegEx")] $WafPolicyCustomRuleConditionOperator,
    [Parameter(Mandatory)][System.Object] $WafPolicyCustomRuleConditionValues,
    [Parameter()][string][ValidateSet("LowerCase", "RemoveNulls", "Trim", "UpperCase", "UrlDecode", "UrlEncode")] $WafPolicyCustomRuleConditionTransforms,
    [Parameter()][string][ValidateSet("MatchRule", "RateLimitRule")] $WafPolicyCustomRuleType = "MatchRule",
    [Parameter()][string][ValidateSet("Allow", "Block", "Log", "Redirect")] $WafPolicyCustomRuleAction = "Block",
    [Parameter()][int] $WafPolicyCustomRulePriority = 100,
    [Parameter()][bool] $WafPolicyCustomRuleConditionNegate = $false
)

#region ===BEGIN IMPORTS===
Import-Module "$PSScriptRoot\..\AzDocs.Common" -Force
#endregion ===END IMPORTS===

Write-Header -ScopedPSCmdlet $PSCmdlet

# Add extension for front-door
Invoke-Executable az config set extension.use_dynamic_install=yes_without_prompt

# Part of the calls get cached for this extension. To make sure we get the latest results from the cli, we are first purging the cache
Invoke-Executable az cache purge

$optionalParameters = @()
if ($WafPolicyCustomRuleConditionTransforms) {
    $optionalParameters += "--transforms", $WafPolicyCustomRuleConditionTransforms
}

$existingMatchConditions = $null;
$existingRule = Invoke-Executable -AllowToFail az network front-door waf-policy rule show --name $WafPolicyCustomRuleName --policy-name $WafPolicyName --resource-group $WafPolicyResourceGroupName
if ($existingRule) {
    $existingMatchConditions = Invoke-Executable az network front-door waf-policy rule match-condition list --name $WafPolicyCustomRuleName --policy-name $WafPolicyName --resource-group $WafPolicyResourceGroupName | ConvertFrom-Json
    if ($existingMatchConditions.count -eq 1) {
        # Since we are not able to update the match conditions without removing and adding again
        # but we cannot remove the match-condition if there is only one
        # we will remove the rule and recreate it.
        Invoke-Executable az network front-door waf-policy rule delete --name $WafPolicyCustomRuleName --policy-name $WafPolicyName --resource-group $WafPolicyResourceGroupName
        Invoke-Executable az network front-door waf-policy rule create --name $WafPolicyCustomRuleName --priority $WafPolicyCustomRulePriority --rule-type $WafPolicyCustomRuleType --action $WafPolicyCustomRuleAction --resource-group $WafPolicyResourceGroupName --policy-name $WafPolicyName --defer
        $existingMatchConditions = $null
    }
    else {
        Invoke-Executable az network front-door waf-policy rule update --name $WafPolicyCustomRuleName --priority $WafPolicyCustomRulePriority --action $WafPolicyCustomRuleAction --resource-group $WafPolicyResourceGroupName --policy-name $WafPolicyName
    }
}
else {
    Invoke-Executable az network front-door waf-policy rule create --name $WafPolicyCustomRuleName --priority $WafPolicyCustomRulePriority --rule-type $WafPolicyCustomRuleType --action $WafPolicyCustomRuleAction --resource-group $WafPolicyResourceGroupName --policy-name $WafPolicyName --defer
}


$existingMatchConditions = Invoke-Executable az network front-door waf-policy rule match-condition list --name $WafPolicyCustomRuleName --policy-name $WafPolicyName --resource-group $WafPolicyResourceGroupName | ConvertFrom-Json
$added = $false
if ($existingMatchConditions -and $existingMatchConditions | Where-Object { $_.matchVariable -eq $WafPolicyCustomRuleConditionMatchVariable -and $_.operator -eq $WafPolicyCustomRuleConditionOperator }) {
    $index = 0
    Write-Host "Found a match condition with the same operator : $WafPolicyCustomRuleConditionOperator and match variable $WafPolicyCustomRuleConditionMatchVariable"
    foreach ($matchCondition in $existingMatchConditions) {
        if ($matchCondition.matchVariable -eq $WafPolicyCustomRuleConditionMatchVariable -and $matchCondition.operator -eq $WafPolicyCustomRuleConditionOperator) {
            Write-Host "Removing existing match-condition"
            Invoke-Executable az network front-door waf-policy rule match-condition remove --index $index --name $WafPolicyCustomRuleName --policy-name $WafPolicyName --resource-group $WafPolicyResourceGroupName
            Write-Host "Adding.."
            Invoke-Executable az network front-door waf-policy rule match-condition add --match-variable $WafPolicyCustomRuleConditionMatchVariable --operator $WafPolicyCustomRuleConditionOperator --values @WafPolicyCustomRuleConditionValues --name $WafPolicyCustomRuleName --resource-group $WafPolicyResourceGroupName --policy-name $WafPolicyName --negate $WafPolicyCustomRuleConditionNegate @optionalParameters
            $added = $true
        }
        $index++
    }
}

if (!$added) {
    Invoke-Executable az network front-door waf-policy rule match-condition add --match-variable $WafPolicyCustomRuleConditionMatchVariable --operator $WafPolicyCustomRuleConditionOperator --values @WafPolicyCustomRuleConditionValues --name $WafPolicyCustomRuleName --resource-group $WafPolicyResourceGroupName --policy-name $WafPolicyName --negate $WafPolicyCustomRuleConditionNegate @optionalParameters
}

Write-Footer -ScopedPSCmdlet $PSCmdlet