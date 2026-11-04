// main template for azure-application-gateway-for-containers
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.azure_application_gateway_for_containers;

// Define outputs below
{
}
