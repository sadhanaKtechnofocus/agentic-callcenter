param uniqueId string
param prefix string
param userAssignedIdentityResourceId string
param voiceWebHookUrl string

resource acsEGTopic 'Microsoft.EventGrid/systemTopics@2023-12-15-preview' existing = {
  name: '${prefix}-acs-topic-${uniqueId}'
}
// EventGrid subscription to invoke voice WebHook to answer incoming calls
resource callEGSub 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2023-12-15-preview' = {
  name: '${prefix}-call-sub-${uniqueId}'
  parent: acsEGTopic
  properties: {
    deliveryWithResourceIdentity: {
      identity: {
        type: 'UserAssigned'
        userAssignedIdentity: userAssignedIdentityResourceId
      }
      destination: {
        endpointType: 'WebHook'
        properties: {
          // NOTE this endpoint MUST be able to handle the initial handshake by EventGrid, otherwise the subscription will fail
          endpointUrl: '${voiceWebHookUrl}/api/call'
        }
      }
    }
    eventDeliverySchema: 'EventGridSchema'
    filter: {
      includedEventTypes: [
        'Microsoft.Communication.IncomingCall'
      ]
    }
  }
}
