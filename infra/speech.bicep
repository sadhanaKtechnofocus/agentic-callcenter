param uniqueId string
param prefix string
param userAssignedIdentityPrincipalId string
param acsIdentityPrincipalId string
param location string = resourceGroup().location

// Azure Speech Service
resource speechService 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: '${prefix}-cogsvc-${uniqueId}'
  location: 'eastus'
  kind: 'AIServices' // MUST be AIServices otherwise it will not work with ACS
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: '${prefix}-cogsvc-${uniqueId}'
    publicNetworkAccess: 'Enabled'
  }
}

// Role assignment for the user-assigned identity (application) to access the Speech Service
resource speechUAMIRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(speechService.id, userAssignedIdentityPrincipalId, 'Cognitive Services Speech User')
  scope: speechService
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', 'f2dc8367-1007-4938-bd23-fe263f013447') // Role definition ID for role
    principalId: userAssignedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Role assignment for the ACS identity to access the Speech Service (for some reason, ACS must use a SystemAssigned identity)
resource speechACSRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(speechService.id, acsIdentityPrincipalId, 'Cognitive Services Speech User')
  scope: speechService
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', 'f2dc8367-1007-4938-bd23-fe263f013447') // Role definition ID for role
    principalId: acsIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

output speechServiceEndpoint string = speechService.properties.endpoint
#disable-next-line outputs-should-not-contain-secrets
output speechServiceKey string = speechService.listKeys().key1
