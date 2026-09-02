using 'main.bicep'

param location = 'swedencentral'
param aksName = 'aks-iq-aks-agent-hol'
param namePrefix = 'opciq'
// acrName is supplied on the command line by scripts/deploy.sh (must be globally unique).
param acrName = readEnvironmentVariable('ACR_NAME', 'opciqacr0000000000')
param imageTag = readEnvironmentVariable('IMAGE_TAG', 'latest')
