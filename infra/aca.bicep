param uniqueId string
param prefix string
param userAssignedIdentityResourceId string
param userAssignedIdentityClientId string
param openAiEndpoint string
param openAiApiKey string
param cosmosDbEndpoint string
param cosmosDbDatabase string
param cosmosDbContainer string
param applicationInsightsConnectionString string
param containerRegistry string = '${prefix}acr${uniqueId}'
param location string = resourceGroup().location
param logAnalyticsWorkspaceName string
param acsEndpoint string
param cognitiveServiceEndpoint string
param speechServiceKey string
param serviceBusNamespaceFqdn string
param searchEndpoint string
param searchIndexName string
param approvalLogicAppUrl string
param openTicketLogicAppUrl string
param uiContainerImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest' //'${containerRegistry}.azurecr.io/telco-callcenter-agents-ui:latest'
param apiContainerImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest' //'${containerRegistry}.azurecr.io/telco-callcenter-agents-api:latest'
param funcContainerImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest' //'${containerRegistry}.azurecr.io/telco-callcenter-agents-func:latest'
param agentsContainerImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest' //'${containerRegistry}.azurecr.io/telco-callcenter-agents-agents:latest'
param voiceContainerImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest' //'${containerRegistry}.azurecr.io/telco-callcenter-agents-voice:latest'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logAnalyticsWorkspaceName
}

// see https://azureossd.github.io/2023/01/03/Using-Managed-Identity-and-Bicep-to-pull-images-with-Azure-Container-Apps/
resource containerAppEnv 'Microsoft.App/managedEnvironments@2023-11-02-preview' = {
  name: '${prefix}-containerAppEnv-${uniqueId}'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityResourceId}': {}
    }
  }
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
  }
}

resource apiContainerApp 'Microsoft.App/containerApps@2022-03-01' = {
  name: '${prefix}-api-${uniqueId}'
  location: location
  tags: {'azd-service-name': 'api' }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityResourceId}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: false
        targetPort: 80
        transport: 'auto'
      }
      registries: [
        {
          server: '${containerRegistry}.azurecr.io'
          identity: userAssignedIdentityResourceId
        }
      ]
    }
    template: {
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
      containers: [
        {
          name: 'api'
          image: apiContainerImage
          resources: {
            cpu: 2
            memory: '4Gi'
          }
          env: [
            // https://learn.microsoft.com/en-us/answers/questions/1225865/unable-to-get-a-user-assigned-managed-identity-wor
            { name: 'AZURE_CLIENT_ID', value: userAssignedIdentityClientId }
            { name: 'APPLICATIONINSIGHTS_CONNECTIONSTRING', value: applicationInsightsConnectionString }
            { name: 'TEAM_REMOTE_URL', value: 'http://${agentsContainerApp.name}:80' }
            { name: 'AZURE_OPENAI_WHISPER_ENDPOINT', value: openAiEndpoint }
            { name: 'AZURE_OPENAI_WHISPER_DEPLOYMENT', value: 'whisper' }
            { name: 'AZURE_OPENAI_WHISPER_KEY', value: '' }
            { name: 'AZURE_OPENAI_WHISPER_VERSION', value: '2024-02-01' }
            { name: 'COSMOSDB_ENDPOINT', value: cosmosDbEndpoint }
            { name: 'COSMOSDB_DATABASE', value: cosmosDbDatabase }
            { name: 'COSMOSDB_CONTAINER', value: cosmosDbContainer }
            { name: 'ACS_ENDPOINT', value: acsEndpoint }
          ]
        }
      ]
    }
  }
}
resource agentsContainerApp 'Microsoft.App/containerApps@2022-03-01' = {
  name: '${prefix}-agents-${uniqueId}'
  location: location
  tags: {'azd-service-name': 'agents' }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityResourceId}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: false
        targetPort: 80
        transport: 'auto'
      }
      registries: [
        {
          server: '${containerRegistry}.azurecr.io'
          identity: userAssignedIdentityResourceId
        }
      ]
    }
    template: {
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
      containers: [
        {
          name: 'agents'
          image: agentsContainerImage
          resources: {
            cpu: 2
            memory: '4Gi'
          }
          env: [
            // https://learn.microsoft.com/en-us/answers/questions/1225865/unable-to-get-a-user-assigned-managed-identity-wor
            { name: 'AZURE_CLIENT_ID', value: userAssignedIdentityClientId }
            { name: 'APPLICATIONINSIGHTS_CONNECTIONSTRING', value: applicationInsightsConnectionString }
            { name: 'AZURE_OPENAI_ENDPOINT', value: openAiEndpoint }
            { name: 'AZURE_OPENAI_MODEL', value: 'gpt-4o' }
            { name: 'AZURE_OPENAI_API_KEY', value: '' }
            { name: 'AZURE_OPENAI_API_VERSION', value: '2024-08-01-preview' }
            { name: 'COSMOSDB_ENDPOINT', value: cosmosDbEndpoint}
            { name: 'COSMOSDB_DATABASE', value: cosmosDbDatabase }
            { name: 'COSMOSDB_CONTAINER', value: cosmosDbContainer }
            { name: 'ACS_ENDPOINT', value: acsEndpoint }
            { name: 'LOGIC_APPS_URL', value: approvalLogicAppUrl }
            { name: 'OPENTICKET_LOGIC_APPS_URL', value: openTicketLogicAppUrl }
            { name: 'AZURE_SEARCH_ENDPOINT', value: searchEndpoint }
            { name: 'AZURE_SEARCH_INDEX', value: searchIndexName }
          ]
        }
      ]
    }
  }
}
resource msgContainerApp 'Microsoft.App/containerApps@2022-03-01' = {
  name: '${prefix}-func-${uniqueId}'
  location: location
  tags: {'azd-service-name': 'functions' }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityResourceId}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: false
        targetPort: 80
        transport: 'auto'
      }
      registries: [
        {
          server: '${containerRegistry}.azurecr.io'
          identity: userAssignedIdentityResourceId
        }
      ]
    }
    template: {
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
      containers: [
        {
          name: 'function'
          image: funcContainerImage
          resources: {
            cpu: 1
            memory: '2Gi'
          }
          env: [
            // https://learn.microsoft.com/en-us/answers/questions/1225865/unable-to-get-a-user-assigned-managed-identity-wor
            { name: 'AZURE_CLIENT_ID', value: userAssignedIdentityClientId }
            { name: 'APPLICATIONINSIGHTS_CONNECTIONSTRING', value: applicationInsightsConnectionString }
            { name: 'ACS_ENDPOINT', value: acsEndpoint }
            // Must be edited to match the channel registration ID
            { name: 'ACS_CHANNEL_REGISTRATION_ID', value: 'd88349b3-801c-4c10-adea-340795d564a6' }
            { name: 'API_BASE_URL', value: 'http://${apiContainerApp.name}' }
            { name: 'ServiceBusConnection__fullyQualifiedNamespace', value: serviceBusNamespaceFqdn }
            { name: 'AZURE_OPENAI_WHISPER_ENDPOINT', value: openAiEndpoint }
            { name: 'AZURE_OPENAI_WHISPER_VERSION', value: '2024-02-01' }
            { name: 'AZURE_OPENAI_WHISPER_DEPLOYMENT', value: 'whisper' }
            { name: 'AZURE_OPENAI_WHISPER_KEY', value: ''}
          ]
        }
      ]
    }
  }
}
resource voiceContainerApp 'Microsoft.App/containerApps@2022-03-01' = {
  name: '${prefix}-voice-${uniqueId}'
  location: location
  tags: {'azd-service-name': 'voice' }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityResourceId}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 80
        transport: 'auto'
      }
      registries: [
        {
          server: '${containerRegistry}.azurecr.io'
          identity: userAssignedIdentityResourceId
        }
      ]
    }
    template: {
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
      containers: [
        {
          name: 'voice'
          image: voiceContainerImage
          resources: {
            cpu: 2
            memory: '4Gi'
          }
          env: [
            // https://learn.microsoft.com/en-us/answers/questions/1225865/unable-to-get-a-user-assigned-managed-identity-wor
            { name: 'AZURE_CLIENT_ID', value: userAssignedIdentityClientId }
            { name: 'APPLICATIONINSIGHTS_CONNECTIONSTRING', value: applicationInsightsConnectionString }
            { name: 'VOICE_NAME', value: 'en-US-AvaMultilingualNeural' }
            { name: 'ACS_ENDPOINT', value: acsEndpoint }
            { name: 'API_BASE_URL', value: 'http://${apiContainerApp.name}' }
            { name: 'COGNITIVE_SERVICE_ENDPOINT', value: cognitiveServiceEndpoint }
          ]
        }
      ]
    }
  }
}

resource uiContainerApp 'Microsoft.App/containerApps@2023-11-02-preview' = {
  name: '${prefix}-ui-${uniqueId}'
  location: location
  tags: {'azd-service-name': 'ui' }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityResourceId}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 80
        transport: 'auto'
      }
      registries: [
        {
          server: '${containerRegistry}.azurecr.io'
          identity: userAssignedIdentityResourceId
        }
      ]
    }
    template: {
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
      containers: [
        {
          name: 'ui'
          image: uiContainerImage
          resources: {
            cpu: 1
            memory: '2Gi'
          }
          env: [
            { name: 'AZURE_CLIENT_ID', value: userAssignedIdentityClientId }
            { name: 'APPLICATIONINSIGHTS_CONNECTIONSTRING', value: applicationInsightsConnectionString }
            { name: 'API_BASE_URL', value: 'http://${apiContainerApp.name}' }
            { name: 'AZURE_OPENAI_WHISPER_ENDPOINT', value: openAiEndpoint }
            { name: 'AZURE_OPENAI_WHISPER_VERSION', value: '2024-02-01' }
            { name: 'AZURE_OPENAI_WHISPER_DEPLOYMENT', value: 'whisper' }
            { name: 'AZURE_OPENAI_WHISPER_KEY', value: '' }
            { name: 'SPEECH_KEY', value: speechServiceKey }
            { name: 'SPEECH_REGION', value: location }
          ]
        }
      ]
    }
  }
}

output voiceEndpoint string = voiceContainerApp.properties.latestRevisionFqdn
