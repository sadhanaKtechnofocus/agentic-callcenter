param uniqueId string
param prefix string
@secure()
param userAssignedIdentityPrincipalId string
param userAssignedIdentityResourceId string
param location string = resourceGroup().location
param currentUserId string

resource search 'Microsoft.Search/searchServices@2024-06-01-preview' = {
  name: '${prefix}-search-${uniqueId}'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityResourceId}': {}
    }
  }
  sku: {
    name: 'standard'
  }
  properties: {
    replicaCount: 1
    partitionCount: 1
    hostingMode: 'default'
    semanticSearch: 'standard'
    disableLocalAuth: true // Force Azure AD auth
  }
}

// Role assignment
resource searchRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(search.id, userAssignedIdentityPrincipalId, 'searchServiceIndexContributor')
  scope: search
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '8ebe5a00-799e-43f5-93ac-243d3dce84a7') // Role definition ID for Contributor
    principalId: userAssignedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}
resource searchAdminRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(search.id, userAssignedIdentityPrincipalId, 'searchServiceContributor')
  scope: search
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '7ca78c08-252a-4471-8644-bb5ff32d4ba0') // Role definition ID for Contributor
    principalId: userAssignedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// Admin role assignment for the current user as well
resource searchRoleAssignmentUser 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(search.id, currentUserId, 'searchServiceIndexContributor')
  scope: search
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '8ebe5a00-799e-43f5-93ac-243d3dce84a7') // Role definition ID for Contributor
    principalId: currentUserId
    principalType: 'User'
  }
}
resource searchAdminRoleAssignmentUser 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(search.id, currentUserId, 'searchServiceContributor')
  scope: search
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '7ca78c08-252a-4471-8644-bb5ff32d4ba0') // Role definition ID for Contributor
    principalId: currentUserId
    principalType: 'User'
  }
}

output endpoint string = 'https://${search.name}.search.windows.net'
output name string = search.name
#disable-next-line outputs-should-not-contain-secrets
output adminKey string = search.listAdminKeys().primaryKey
