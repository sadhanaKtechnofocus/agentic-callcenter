param uniqueId string
param prefix string
param userAssignedIdentityPrincipalId string
param userAssignedIdentityResourceId string
param communicationServiceDataLocation string = 'United States'
param location string = resourceGroup().location

resource emailService 'Microsoft.Communication/emailServices@2023-04-01-preview' = {
  name: '${prefix}-email-${uniqueId}'
  location: 'global'
  properties: {
    dataLocation: communicationServiceDataLocation
  }
}

// resource acsEmailDomain 'Microsoft.Communication/emailServices/domains@2023-04-01-preview' = {
//   name: 'AzureManagedDomain'
//   parent: emailService
//   location: 'global'
//   properties: {
//     domainManagement: 'AzureManaged'
//     userEngagementTracking: 'Disabled'
//   }
// }

resource acs 'Microsoft.Communication/CommunicationServices@2023-04-01-preview' = {
  name: '${prefix}-acs-${uniqueId}'
  location: 'global'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    dataLocation: communicationServiceDataLocation
    linkedDomains: [
      // acsEmailDomain.id
    ]
  }
}

resource acsRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(acs.id, userAssignedIdentityPrincipalId, 'contributor')
  scope: acs
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', 'b24988ac-6180-42a0-ab88-20f7382dd24c') // Role definition ID for Contributor
    principalId: userAssignedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// A service bus queue to store events
resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: '${prefix}-sb-${uniqueId}'
  location: location
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
}

// SB Data Owner role assignment for the service bus namespace
resource sbRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(serviceBusNamespace.id, userAssignedIdentityPrincipalId, 'dataowner')
  scope: serviceBusNamespace
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '090c5cfd-751d-490a-894a-3ce6f1109419')
    principalId: userAssignedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource smsQueue 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = {
  name: 'sms'
  parent: serviceBusNamespace
  properties: {}
}
resource advMsgQueue 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = {
  name: 'messages'
  parent: serviceBusNamespace
  properties: {}
}
resource callQueue 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = {
  name: 'calls'
  parent: serviceBusNamespace
  properties: {}
}

// An EventGrid topic to receive events from the communication service
resource acsEGTopic 'Microsoft.EventGrid/systemTopics@2023-12-15-preview' = {
  name: '${prefix}-acs-topic-${uniqueId}'
  location: 'global'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityResourceId}': {}
    }
  }
  properties: {
    source: acs.id
    topicType: 'Microsoft.Communication.CommunicationServices'
  }
}

// An EventGrid subscription to forward events to the service bus queue
resource smsEGSub 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2023-12-15-preview' = {
  name: '${prefix}-sms-sub-${uniqueId}'
  parent: acsEGTopic
  properties: {
    deliveryWithResourceIdentity: {
      identity: {
        type: 'UserAssigned'
        userAssignedIdentity: userAssignedIdentityResourceId
      }
      destination: {
        endpointType: 'ServiceBusQueue'
        properties: {
          resourceId: smsQueue.id
        }
      }
    }
    eventDeliverySchema: 'EventGridSchema'
    filter: {
      includedEventTypes: [
        'Microsoft.Communication.SMSReceived'
      ]
    }
  }
}
// An EventGrid subscription to forward events to the service bus queue
resource msgEGSub 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2023-12-15-preview' = {
  name: '${prefix}-msg-sub-${uniqueId}'
  parent: acsEGTopic
  properties: {
    deliveryWithResourceIdentity: {
      identity: {
        type: 'UserAssigned'
        userAssignedIdentity: userAssignedIdentityResourceId
      }
      destination: {
        endpointType: 'ServiceBusQueue'
        properties: {
          resourceId: advMsgQueue.id
        }
      }
    }
    eventDeliverySchema: 'EventGridSchema'
    filter: {
      includedEventTypes: [
        'Microsoft.Communication.AdvancedMessageReceived'
        'Microsoft.Communication.AdvancedMessageDeliveryStatusUpdated'
      ]
    }
  }
}

output acsName string = acs.name
output acsEndpoint string = acs.properties.hostName
output acsTopicName string = acsEGTopic.name
output acsTopicId string = acsEGTopic.id
// output acsEmailDomainName string = acsEmailDomain.name
// output acsEmailSender string = 'donotreply@${acsEmailDomain.properties.mailFromSenderDomain}'
output sbNamespace string = serviceBusNamespace.name
output sbNamespaceFQDN string = serviceBusNamespace.properties.serviceBusEndpoint
output smsQueueName string = smsQueue.name
output advMsgQueueName string = advMsgQueue.name
output callQueueName string = callQueue.name
output acsIdentityId string = acs.identity.principalId
