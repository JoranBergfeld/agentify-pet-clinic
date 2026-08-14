targetScope = 'subscription'

@minLength(1)
param environmentName string

param location string
param modelName string = 'gpt-5.4-mini'
param modelVersion string = '2026-03-17'
param modelDeploymentName string = 'gpt-5-4-mini'
param modelDeploymentSku string = 'GlobalStandard'

@minValue(1)
param modelDeploymentCapacity int = 10

param tags object = {
  'azd-env-name': environmentName
  purpose: 'agentic-engineering-workshop'
}

var resourceGroupName = 'rg-${environmentName}'

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

module resources 'resources.bicep' = {
  name: 'workshop-resources'
  scope: resourceGroup
  params: {
    environmentName: environmentName
    location: location
    modelName: modelName
    modelVersion: modelVersion
    modelDeploymentName: modelDeploymentName
    modelDeploymentSku: modelDeploymentSku
    modelDeploymentCapacity: modelDeploymentCapacity
    tags: tags
  }
}

output AZURE_LOCATION string = location
output AZURE_RESOURCE_GROUP_NAME string = resourceGroup.name
output AZURE_SUBSCRIPTION_ID string = subscription().subscriptionId
output AZURE_TENANT_ID string = tenant().tenantId
output SERVICE_WEB_NAME string = resources.outputs.webAppName
output WEB_APP_URL string = resources.outputs.webAppUrl
output AZURE_OPENAI_ACCOUNT_NAME string = resources.outputs.foundryName
output AZURE_OPENAI_ENDPOINT string = resources.outputs.openAiEndpoint
output AZURE_OPENAI_DEPLOYMENT string = modelDeploymentName
output AZURE_OPENAI_MODEL string = modelName
output AZURE_OPENAI_MODEL_VERSION string = modelVersion
output AZURE_OPENAI_DEPLOYMENT_SKU string = modelDeploymentSku
output AZURE_OPENAI_DEPLOYMENT_CAPACITY int = modelDeploymentCapacity
