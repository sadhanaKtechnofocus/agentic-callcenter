param uniqueId string
param prefix string
param userAssignedIdentityResourceId string
param location string = resourceGroup().location
param emailRecipientAddress string

// Microsoft.Web/connections resource to Outlook 365
module office365Connection 'br/public:avm/res/web/connection:0.4.1' = {
  name: 'office365'
  scope: resourceGroup()
  params: {
    name: 'office365'
    api: {
      id: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/${location}/managedApis/office365'
    }
    displayName: 'office365'
  }
}

module sendEmailLogic 'br/public:avm/res/logic/workflow:0.4.0' = {
  name: 'sendEmailLogic'
  scope: resourceGroup()
  params: {
    name: '${prefix}-sendemail-${uniqueId}'
    location: location
    managedIdentities: { userAssignedResourceIds: [userAssignedIdentityResourceId] }
    // diagnosticSettings: [
    //   {
    //     name: 'customSetting'
    //     metricCategories: [
    //       {
    //         category: 'AllMetrics'
    //       }
    //     ]
    //     workspaceResourceId: monitoring.outputs.logAnalyticsWorkspaceId
    //   }
    // ]
    workflowActions: loadJsonContent('./logicapps/book-technician.actions.json')
    workflowTriggers: loadJsonContent('./logicapps/book-technician.triggers.json')
    workflowParameters: loadJsonContent('./logicapps/book-technician.parameters.json')
    definitionParameters: {
      recipientAddress: {
        value: emailRecipientAddress
      }
      '$connections': {
        value: {
          office365: {
            id: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/${location}/managedApis/office365'
            connectionId: office365Connection.outputs.resourceId
            connectionName: office365Connection.name
          }
        }
      }
    }
  }
}

module openTicketLogic 'br/public:avm/res/logic/workflow:0.4.0' = {
  name: 'openTicketLogic'
  scope: resourceGroup()
  params: {
    name: '${prefix}-openticket-${uniqueId}'
    location: location
    managedIdentities: { userAssignedResourceIds: [userAssignedIdentityResourceId] }
    // diagnosticSettings: [
    //   {
    //     name: 'customSetting'
    //     metricCategories: [
    //       {
    //         category: 'AllMetrics'
    //       }
    //     ]
    //     workspaceResourceId: monitoring.outputs.logAnalyticsWorkspaceId
    //   }
    // ]
    workflowActions: loadJsonContent('./logicapps/open-ticket.actions.json')
    workflowTriggers: loadJsonContent('./logicapps/open-ticket.triggers.json')
    workflowParameters: loadJsonContent('./logicapps/open-ticket.parameters.json')
    definitionParameters: {
      recipientAddress: {
        value: emailRecipientAddress
      }
      '$connections': {
        value: {
          office365: {
            id: '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Web/locations/${location}/managedApis/office365'
            connectionId: office365Connection.outputs.resourceId
            connectionName: office365Connection.name
          }
        }
      }
    }
  }
}

module approveServiceUrl './logicapps/retrieve_http_trigger.bicep' = {
  name: 'approveServiceUrl'
  scope: resourceGroup()
  params: {
    logicAppName: '${prefix}-sendemail-${uniqueId}'
    triggerName: 'HTTP'
  }
  dependsOn: [sendEmailLogic]
}
module openTicketUrl './logicapps/retrieve_http_trigger.bicep' = {
  name: 'openTicketUrl'
  scope: resourceGroup()
  params: {
    logicAppName: '${prefix}-openticket-${uniqueId}'
    triggerName: 'HTTP'
  }
  dependsOn: [sendEmailLogic]
}

output approveServiceUrl string = approveServiceUrl.outputs.url
output openTicketUrl string = openTicketUrl.outputs.url
