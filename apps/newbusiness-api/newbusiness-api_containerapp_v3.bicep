param appName string = 'test-app'
param environmentName string = 'digital-apps-env'
param subscriptionId string

@description('Environment variables as an array of key-value objects')
param environmentVariables array = [
  {
    name: 'DB_TYPE'
    value: 'SQL'
  }
  {
    name: 'LOG_LEVEL'
    value: 'debug'
  }
]

param location string
param resourceGroupName string // The resource group where the Container App will be deployed

// Container App Environment parameters
 param logAnalyticsWorkspaceId string // Existing Log Analytics Workspace ID for the environment

// Container App specific parameters
param containerImage string // e.g., 'youracr.azurecr.io/your-app:latest'
param targetPort int // The port your application listens on inside the container
param minReplicas int = 1 // Minimum number of replicas
param maxReplicas int = 10 // Maximum number of replicas

// Ingress (HTTP/HTTPS) configuration
param ingressEnabled bool = true
param ingressExternal bool = true // True for external access, false for internal only
param allowInsecure bool = false // Allow HTTP connections (redirects to HTTPS if false)
param customDomains array = [] // Array of objects: [{ hostName: 'my.custom.com', certificateThumbprint: '...' }]

// Dapr configuration (optional)
param daprEnabled bool = false
param daprAppId string = ''
param daprAppPort int = 0
param daprComponents array = [] // Array of objects: [{ name: 'compName', type: 'compType', version: 'v1', properties: [{ name: 'propName', value: 'propValue' }] }]

// VNet Integration (optional)
param vnetIntegrationSubnetId string = '' // Resource ID of the subnet for VNet integration

param secrets array = []

resource managedEnvironments_test_env_name_resource 'Microsoft.App/managedEnvironments@2025-01-01' = {
  name: environmentName
  location: location
  properties: {
    appLogsConfiguration: {}
    zoneRedundant: false
    kedaConfiguration: {}
    daprConfiguration: {}
    customDomainConfiguration: {}
    workloadProfiles: [
      {
        workloadProfileType: 'Consumption'
        name: 'Consumption'
      }
    ]
    peerAuthentication: {
      mtls: {
        enabled: false
      }
    }
    peerTrafficConfiguration: {
      encryption: {
        enabled: false
      }
    }
  }
}

resource containerapps_test_app_name_resource 'Microsoft.App/containerapps@2025-01-01' = {
  name: appName
  location: location
  identity: {
    type: 'None'
  }
  properties: {
    managedEnvironmentId: managedEnvironments_test_env_name_resource.id
    environmentId: managedEnvironments_test_env_name_resource.id
    workloadProfileName: 'Consumption'
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {        
        external: ingressExternal
        targetPort: targetPort
        //exposedPort: targetPort
        transport: 'Auto'
        traffic: [
          {
            weight: 100
            latestRevision: true
          }
        ]
        allowInsecure: false
        stickySessions: {
          affinity: 'none'
        }
      }
      identitySettings: []
    }
    template: {
      containers: [
        {
          image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
          name: appName
          resources: {
            cpu: json('0.5')
            memory: '1Gi'
          }
         env: [
            for envVar in environmentVariables: {
                name: envVar.name
                value: envVar.value
            }
          ] 
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
        cooldownPeriod: 300
        pollingInterval: 30
      }
    }
  }
}
