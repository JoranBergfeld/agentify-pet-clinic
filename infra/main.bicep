targetScope = 'subscription'

@minLength(1)
param environmentName string

param location string

param modelDeploymentSku string = 'GlobalStandard'

param tags object = {
  'azd-env-name': environmentName
  purpose: 'wayfinder-15-prototype'
}

var resourceGroupName = 'rg-${environmentName}'

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

module resources 'resources.bicep' = {
  name: 'resources'
  scope: resourceGroup
  params: {
    environmentName: environmentName
    location: location
    modelDeploymentSku: modelDeploymentSku
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
output AZURE_OPENAI_DEPLOYMENT string = resources.outputs.modelDeploymentName
output AZURE_OPENAI_MODEL string = resources.outputs.modelName
