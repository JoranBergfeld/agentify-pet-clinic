param environmentName string
param location string
param modelDeploymentSku string
param tags object

var token = uniqueString(resourceGroup().id, environmentName)
var planName = 'plan-${token}'
var webAppName = 'petclinic-${token}'
var foundryName = 'foundry-${token}'
var modelName = 'gpt-5.4-mini'
var modelVersion = '2026-03-17'
var modelDeploymentName = 'gpt-5-4-mini'
var foundryUserRoleDefinitionId = subscriptionResourceId(
  'Microsoft.Authorization/roleDefinitions',
  '53ca6127-db72-4b80-b1b0-d745d6d5456d'
)

resource plan 'Microsoft.Web/serverfarms@2024-11-01' = {
  name: planName
  location: location
  kind: 'linux'
  tags: tags
  sku: {
    name: 'B1'
    tier: 'Basic'
    size: 'B1'
    capacity: 1
  }
  properties: {
    reserved: true
  }
}

resource foundry 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: foundryName
  location: location
  kind: 'AIServices'
  tags: tags
  sku: {
    name: 'S0'
  }
  properties: {
    allowProjectManagement: true
    customSubDomainName: foundryName
    disableLocalAuth: true
    publicNetworkAccess: 'Enabled'
  }
}

resource modelDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-06-01' = {
  parent: foundry
  name: modelDeploymentName
  sku: {
    name: modelDeploymentSku
    capacity: 10
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: modelName
      version: modelVersion
    }
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
  }
}

resource web 'Microsoft.Web/sites@2024-11-01' = {
  name: webAppName
  location: location
  kind: 'app,linux'
  tags: union(tags, {
    'azd-service-name': 'web'
  })
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      alwaysOn: true
      ftpsState: 'Disabled'
      http20Enabled: true
      linuxFxVersion: 'JAVA|21-java21'
      minTlsVersion: '1.2'
      appSettings: [
        {
          name: 'AZURE_OPENAI_ENDPOINT'
          value: 'https://${foundry.name}.openai.azure.com'
        }
        {
          name: 'AZURE_OPENAI_MICROSOFT_FOUNDRY'
          value: 'true'
        }
        {
          name: 'AZURE_OPENAI_DEPLOYMENT'
          value: modelDeploymentName
        }
        {
          name: 'AZURE_OPENAI_MODEL'
          value: modelName
        }
        {
          name: 'JAVA_OPTS'
          value: '-Xms256m -Xmx1024m'
        }
        {
          name: 'WEBSITES_PORT'
          value: '8080'
        }
      ]
    }
  }
  dependsOn: [
    modelDeployment
  ]
}

resource foundryUser 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(foundry.id, web.id, foundryUserRoleDefinitionId)
  scope: foundry
  properties: {
    principalId: web.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: foundryUserRoleDefinitionId
  }
}

output webAppName string = web.name
output webAppUrl string = 'https://${web.properties.defaultHostName}'
output foundryName string = foundry.name
output openAiEndpoint string = 'https://${foundry.name}.openai.azure.com'
output modelDeploymentName string = modelDeploymentName
output modelName string = modelName
