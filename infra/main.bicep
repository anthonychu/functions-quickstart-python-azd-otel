targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
@allowed(['australiaeast', 'eastasia', 'eastus', 'eastus2', 'northeurope', 'southcentralus', 'southeastasia', 'swedencentral', 'uksouth', 'westus2', 'eastus2euap'])
@metadata({
  azd: {
    type: 'location'
  }
})
param location string

param processorServiceName string = ''
param processorUserAssignedIdentityName string = ''
param processorTsServiceName string = ''
param processorTsUserAssignedIdentityName string = ''
param applicationInsightsName string = ''
param appServicePlanName string = ''
param logAnalyticsName string = ''
param resourceGroupName string = ''
param storageAccountName string = ''
param storageAccountNameTs string = ''
param serviceBusQueueName string = ''
param serviceBusNamespaceName string = ''
param vNetName string = ''

param vnetEnabled bool

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }
// Generate a unique function app name if one is not provided.
var appName = !empty(processorServiceName) ? processorServiceName : '${abbrs.webSitesFunctions}${resourceToken}'
var appNameTs = !empty(processorTsServiceName) ? processorTsServiceName : '${abbrs.webSitesFunctions}ts-${resourceToken}'
// Generate a unique container name that will be used for deployments.
var deploymentStorageContainerName = 'app-package-${take(appName, 32)}-${take(resourceToken, 7)}'
var deploymentStorageContainerNameTs = 'app-package-${take(appNameTs, 32)}-${take(resourceToken, 7)}'
@description('Id of the user or app to assign application roles')
param principalId string = ''
var principalIds = !empty(principalId) ? [processorUserAssignedIdentity.outputs.principalId, processorTsUserAssignedIdentity.outputs.principalId, principalId] : [processorUserAssignedIdentity.outputs.principalId, processorTsUserAssignedIdentity.outputs.principalId]

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

// User assigned managed identity to be used by the Function App to reach storage and service bus
module processorUserAssignedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.1' = {
  name: 'processorUserAssignedIdentity'
  scope: rg
  params: {
    name: !empty(processorUserAssignedIdentityName) ? processorUserAssignedIdentityName : '${abbrs.managedIdentityUserAssignedIdentities}processor-${resourceToken}'
    location: location
    tags: tags
  }
}

// User assigned managed identity for TypeScript Function App
module processorTsUserAssignedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.4.1' = {
  name: 'processorTsUserAssignedIdentity'
  scope: rg
  params: {
    name: !empty(processorTsUserAssignedIdentityName) ? processorTsUserAssignedIdentityName : '${abbrs.managedIdentityUserAssignedIdentities}processor-ts-${resourceToken}'
    location: location
    tags: tags
  }
}

// The application backend
module processor './app/processor.bicep' = {
  name: 'processor'
  scope: rg
  params: {
    name: appName
    location: location
    tags: tags
    applicationInsightsName: monitoring.outputs.name
    appServicePlanId: appServicePlan.outputs.resourceId
    runtimeName: 'python'
    runtimeVersion: '3.12'
    storageAccountName: storage.outputs.name
    identityId: processorUserAssignedIdentity.outputs.resourceId
    identityClientId: processorUserAssignedIdentity.outputs.clientId
    appSettings: {
    }
    virtualNetworkSubnetId: vnetEnabled ? '${serviceVirtualNetwork.?outputs.resourceId}/subnets/app' : ''
    serviceBusQueueName: !empty(serviceBusQueueName) ? serviceBusQueueName : '${abbrs.serviceBusNamespacesQueues}${resourceToken}'
    serviceBusNamespaceFQDN: '${serviceBus.outputs.name}.servicebus.windows.net'
    deploymentStorageContainerName: deploymentStorageContainerName
  }
}

// The TypeScript application backend
module processorTs './app/processor-ts.bicep' = {
  name: 'processor-ts'
  scope: rg
  params: {
    name: appNameTs
    location: location
    tags: tags
    applicationInsightsName: monitoring.outputs.name
    appServicePlanId: appServicePlan.outputs.resourceId
    runtimeName: 'node'
    runtimeVersion: '20'
    storageAccountName: storageTs.outputs.name
    identityId: processorTsUserAssignedIdentity.outputs.resourceId
    identityClientId: processorTsUserAssignedIdentity.outputs.clientId
    appSettings: {
    }
    virtualNetworkSubnetId: vnetEnabled ? '${serviceVirtualNetwork.?outputs.resourceId}/subnets/app' : ''
    serviceBusQueueName: !empty(serviceBusQueueName) ? serviceBusQueueName : '${abbrs.serviceBusNamespacesQueues}${resourceToken}'
    serviceBusNamespaceFQDN: '${serviceBus.outputs.name}.servicebus.windows.net'
    deploymentStorageContainerName: deploymentStorageContainerNameTs
  }
}

// Backing storage for Azure functions processor
module storage 'br/public:avm/res/storage/storage-account:0.8.3' = {
  name: 'storage'
  scope: rg
  params: {
    name: !empty(storageAccountName) ? storageAccountName : '${abbrs.storageStorageAccounts}${resourceToken}'
    location: location
    tags: tags
    publicNetworkAccess: vnetEnabled ? 'Disabled' : 'Enabled'
    networkAcls: vnetEnabled ? {
      defaultAction: 'Deny'
      bypass: 'None'
    } : {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
    blobServices: {
      containers: [
        {
          name: deploymentStorageContainerName
          publicAccess: 'None'
        }
      ]
    }
    skuName: 'Standard_LRS'
    allowSharedKeyAccess: false
    minimumTlsVersion: 'TLS1_2'
  }
}

// Backing storage for TypeScript Azure functions processor
module storageTs 'br/public:avm/res/storage/storage-account:0.8.3' = {
  name: 'storageTs'
  scope: rg
  params: {
    name: !empty(storageAccountNameTs) ? storageAccountNameTs : '${abbrs.storageStorageAccounts}ts${resourceToken}'
    location: location
    tags: tags
    publicNetworkAccess: vnetEnabled ? 'Disabled' : 'Enabled'
    networkAcls: vnetEnabled ? {
      defaultAction: 'Deny'
      bypass: 'None'
    } : {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
    blobServices: {
      containers: [
        {
          name: deploymentStorageContainerNameTs
          publicAccess: 'None'
        }
      ]
    }
    skuName: 'Standard_LRS'
    allowSharedKeyAccess: false
    minimumTlsVersion: 'TLS1_2'
  }
}

//Storage Blob Data Owner role, Storage Blob Data Contributor role, Storage Table Data Contributor role
// Allow access from API to storage account using a managed identity and Storage Blob Data Contributor and Data Owner role
var roleIds = ['b7e6dc6d-f1e8-4753-8033-0f276bb0955b', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe', '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3']
module storageBlobDataOwnerRoleDefinitionApi 'app/storage-Access.bicep' = [for roleId in roleIds: {
  name: 'blobDataOwner${roleId}'
  scope: rg
  params: {
    storageAccountName: storage.outputs.name
    roleId: roleId
    principalIds: principalIds
  }
}]

// Allow access from TypeScript API to storage account
module storageTsBlobDataOwnerRoleDefinitionApi 'app/storage-Access.bicep' = [for roleId in roleIds: {
  name: 'blobDataOwnerTs${roleId}'
  scope: rg
  params: {
    storageAccountName: storageTs.outputs.name
    roleId: roleId
    principalIds: principalIds
  }
}]

module appServicePlan 'br/public:avm/res/web/serverfarm:0.1.1' = {
  name: 'appserviceplan'
  scope: rg
  params: {
    name: !empty(appServicePlanName) ? appServicePlanName : '${abbrs.webServerFarms}${resourceToken}'
    location: location
    tags: tags
    sku: {
      name: 'FC1'
      tier: 'FlexConsumption'
    }
    reserved: true
  }
}

// Service Bus
module serviceBus 'br/public:avm/res/service-bus/namespace:0.9.0' = {
  name: 'serviceBus'
  scope: rg
  params: {
    name: !empty(serviceBusNamespaceName) ? serviceBusNamespaceName : '${abbrs.serviceBusNamespaces}${resourceToken}'
    location: location
    tags: tags
    skuObject: {
      name: 'Premium'
    }
    publicNetworkAccess: vnetEnabled ? 'Disabled' : 'Enabled'
    queues: [
      {
        name: !empty(serviceBusQueueName) ? serviceBusQueueName : '${abbrs.serviceBusNamespacesQueues}${resourceToken}'
      }
    ]
  }
}

var ServiceBusRoleDefinitionIds  = ['090c5cfd-751d-490a-894a-3ce6f1109419', '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0'] //Azure Service Bus Data Owner and Data Receiver roles
// Allow access from processor to Service Bus using a managed identity and Azure Service Bus Data Owner and Data Receiver roles
module ServiceBusDataOwnerRoleAssignment 'app/servicebus-Access.bicep' = [for roleId in ServiceBusRoleDefinitionIds: {
  name: 'sbRoleAssignment${roleId}'
  scope: rg
  params: {
    serviceBusNamespaceName: serviceBus.outputs.name
    roleDefinitionId: roleId
    principalIds: principalIds
  }
}]

// Monitoring Metrics Publisher role assignment for Application Insights  
module appInsightsMetricsPublisherRole 'app/appinsights-Access.bicep' = {
  name: 'appInsightsMetricsPublisher'
  scope: rg
  params: {
    applicationInsightsName: monitoring.outputs.name
    roleId: '3913510d-42f4-4e42-8a64-420c390055eb' // Monitoring Metrics Publisher
    principalIds: principalIds
  }
}

// Virtual Network & private endpoint
module serviceVirtualNetwork 'br/public:avm/res/network/virtual-network:0.6.1' = if (vnetEnabled) {
  name: 'serviceVirtualNetwork'
  scope: rg
  params: {
    name: !empty(vNetName) ? vNetName : '${abbrs.networkVirtualNetworks}${resourceToken}'
    location: location
    tags: tags
    addressPrefixes: [
      '10.0.0.0/16'
    ]
    subnets: [
      {
        name: 'sb'
        addressPrefix: '10.0.1.0/24'
        privateEndpointNetworkPolicies: 'Disabled'
        privateLinkServiceNetworkPolicies: 'Enabled'
      }
      {
        name: 'app'
        addressPrefix: '10.0.2.0/23'
        privateEndpointNetworkPolicies: 'Disabled'
        privateLinkServiceNetworkPolicies: 'Enabled'
        delegation: 'Microsoft.App/environments'
      }
      {
        name: 'st'
        addressPrefix: '10.0.4.0/24'
        privateEndpointNetworkPolicies: 'Disabled'
        privateLinkServiceNetworkPolicies: 'Enabled'
      }
    ]
  }
}

module servicePrivateEndpoint 'app/servicebus-privateEndpoint.bicep' = if (vnetEnabled) {
  name: 'servicePrivateEndpoint'
  scope: rg
  params: {
    location: location
    tags: tags
    virtualNetworkName: !empty(vNetName) ? vNetName : '${abbrs.networkVirtualNetworks}${resourceToken}'
    subnetName: 'sb'
    sbNamespaceId: serviceBus.outputs.resourceId
  }
}

module storagePrivateEndpoint 'app/storage-PrivateEndpoint.bicep' = if (vnetEnabled) {
  name: 'storagePrivateEndpoint'
  scope: rg
  params: {
    location: location
    tags: tags
    virtualNetworkName: !empty(vNetName) ? vNetName : '${abbrs.networkVirtualNetworks}${resourceToken}'
    subnetName: 'st'
    resourceName: storage.outputs.name
  }
}

module storageTsPrivateEndpoint 'app/storage-PrivateEndpoint.bicep' = if (vnetEnabled) {
  name: 'storageTsPrivateEndpoint'
  scope: rg
  params: {
    location: location
    tags: tags
    virtualNetworkName: !empty(vNetName) ? vNetName : '${abbrs.networkVirtualNetworks}${resourceToken}'
    subnetName: 'st'
    resourceName: storageTs.outputs.name
  }
}

// Monitor application with Azure Monitor - Log Analytics and Application Insights
module logAnalytics 'br/public:avm/res/operational-insights/workspace:0.11.1' = {
  name: '${uniqueString(deployment().name, location)}-loganalytics'
  scope: rg
  params: {
    name: !empty(logAnalyticsName) ? logAnalyticsName : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    location: location
    tags: tags
    dataRetention: 30
  }
}

module monitoring 'br/public:avm/res/insights/component:0.6.0' = {
  name: '${uniqueString(deployment().name, location)}-appinsights'
  scope: rg
  params: {
    name: !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.insightsComponents}${resourceToken}'
    location: location
    tags: tags
    workspaceResourceId: logAnalytics.outputs.resourceId
    disableLocalAuth: true
  }
}

// App outputs
output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output SERVICE_PROCESSOR_NAME string = processor.outputs.SERVICE_PROCESSOR_NAME
output AZURE_FUNCTION_NAME string = processor.outputs.SERVICE_PROCESSOR_NAME
output SERVICE_PROCESSOR_TS_NAME string = processorTs.outputs.SERVICE_PROCESSOR_NAME
output AZURE_FUNCTION_TS_NAME string = processorTs.outputs.SERVICE_PROCESSOR_NAME
