// Azure Container Apps dynamic session pool = the sandbox "node" that agents use
// for isolated Python code execution (Fabric IQ / Monty CodeAct offload target).
// Mirrors the ACA Sandboxes reference: https://github.com/Azure-Samples/azure-container-apps-sandboxes
param name string
param location string
param environmentId string
param maxConcurrentSessions int = 20
param cooldownPeriodInSeconds int = 300

resource pool 'Microsoft.App/sessionPools@2024-10-02-preview' = {
  name: name
  location: location
  properties: {
    environmentId: environmentId
    poolManagementType: 'Dynamic'
    containerType: 'PythonLTS'
    scaleConfiguration: {
      maxConcurrentSessions: maxConcurrentSessions
    }
    dynamicPoolConfiguration: {
      executionType: 'Timed'
      cooldownPeriodInSeconds: cooldownPeriodInSeconds
    }
    sessionNetworkConfiguration: {
      status: 'EgressDisabled'
    }
  }
}

output name string = pool.name
output poolManagementEndpoint string = pool.properties.poolManagementEndpoint
