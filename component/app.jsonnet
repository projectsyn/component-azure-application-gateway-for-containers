local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.azure_application_gateway_for_containers;
local argocd = import 'lib/argocd.libjsonnet';

local app = argocd.App('azure-application-gateway-for-containers', params.namespace);

local appPath =
  local project = std.get(std.get(app, 'spec', {}), 'project', 'syn');
  if project == 'syn' then 'apps' else 'apps-%s' % project;

{
  ['%s/azure-application-gateway-for-containers' % appPath]: app,
}
