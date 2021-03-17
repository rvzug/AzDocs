[CmdletBinding()]
param (
    [Parameter(Mandatory)][string] $FunctionAppResourceGroupName,
    [Parameter(Mandatory)][string] $FunctionAppName,
    [Alias("VnetName")]
    [Parameter(Mandatory)][string] $FunctionAppVnetIntegrationName,
    [Parameter(Mandatory)][string] $FunctionAppVnetIntegrationSubnetName,
    [Parameter()][string] $FunctionAppServiceDeploymentSlotName
)

#region ===BEGIN IMPORTS===
Import-Module "$PSScriptRoot\..\AzDocs.Common" -Force
#endregion ===END IMPORTS===

Write-Header -ScopedPSCmdlet $PSCmdlet

$fullFunctionAppName = $FunctionAppName
$additionalParameters = @()

if ($FunctionAppServiceDeploymentSlotName) {
    $additionalParameters += '--slot' , $FunctionAppServiceDeploymentSlotName
    $fullFunctionAppName += " [$FunctionAppServiceDeploymentSlotName]"
}

$vnetIntegrations = Invoke-Executable az functionapp vnet-integration list --resource-group $FunctionAppResourceGroupName --name $FunctionAppName @additionalParameters | ConvertFrom-Json
$matchedIntegrations = $vnetIntegrations | Where-Object  vnetResourceId -like "*/providers/Microsoft.Network/virtualNetworks/$FunctionAppVnetIntegrationName/subnets/$FunctionAppVnetIntegrationSubnetName"
if($matchedIntegrations)
{
    Write-Host "VNET Integration found for $fullFunctionAppName"
}
else
{
    Write-Host "VNET Integration not found, adding it to $fullFunctionAppName"
    Invoke-Executable az functionapp vnet-integration add --resource-group $FunctionAppResourceGroupName --name $FunctionAppName --vnet $FunctionAppVnetIntegrationName --subnet $FunctionAppVnetIntegrationSubnetName @additionalParameters
    Invoke-Executable az functionapp restart --name $FunctionAppName --resource-group $FunctionAppResourceGroupName
}

# Set WEBSITE_VNET_ROUTE_ALL=1 for vnet integration
Invoke-Executable az functionapp config appsettings set --resource-group $FunctionAppResourceGroupName --name $FunctionAppName --settings "WEBSITE_VNET_ROUTE_ALL=1"

Write-Footer -ScopedPSCmdlet $PSCmdlet