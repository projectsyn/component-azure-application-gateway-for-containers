// main template for azure-application-gateway-for-containers
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.azure_application_gateway_for_containers;

local albId =
  local missing = [
    key
    for key in [ 'subscription_id', 'resource_group', 'name' ]
    if params.alb[key] == null
  ];
  assert std.length(missing) == 0 :
         'parameters alb.%s must be set' % std.join(', alb.', missing);
  '/subscriptions/%(subscription_id)s/resourceGroups/%(resource_group)s/providers/Microsoft.ServiceNetworking/trafficControllers/%(name)s' % params.alb;

local namespace = kube.Namespace(params.namespace);

// Shared Gateway on the Terraform-managed (BYO) Application Gateway for Containers.
local gateway = kube._Object('gateway.networking.k8s.io/v1', 'Gateway', params.gateway.name) {
  metadata+: {
    namespace: params.namespace,
    annotations+: params.gateway.annotations {
      'alb.networking.azure.io/alb-id': albId,
    },
  },
  spec: {
    gatewayClassName: 'azure-alb-external',
    addresses: [
      {
        type: 'alb.networking.azure.io/alb-frontend',
        value: params.alb.frontend,
      },
    ],
    // Lets namespaces attach their own listeners (hostnames, certificates) via ListenerSets.
    [if params.gateway.allowedListeners != null then 'allowedListeners']: params.gateway.allowedListeners,
    listeners: [
      { name: name } + params.gateway.listeners[name]
      for name in std.objectFields(params.gateway.listeners)
      if params.gateway.listeners[name] != null
    ],
  },
};

// Gateway API resources cluster users may manage in their namespaces.
// The AKS-managed Gateway API CRDs don't ship aggregated roles, so the default `admin`, `edit` and `view` ClusterRoles don't cover them.
local userResources = [ 'httproutes', 'grpcroutes', 'referencegrants', 'listenersets' ];

local viewRole = kube._Object('rbac.authorization.k8s.io/v1', 'ClusterRole', 'syn-gateway-api-view') {
  metadata+: {
    labels+: {
      'rbac.authorization.k8s.io/aggregate-to-admin': 'true',
      'rbac.authorization.k8s.io/aggregate-to-edit': 'true',
      'rbac.authorization.k8s.io/aggregate-to-view': 'true',
    },
  },
  rules: [
    {
      apiGroups: [ 'gateway.networking.k8s.io' ],
      resources: [ 'gateways' ] + userResources,
      verbs: [ 'get', 'list', 'watch' ],
    },
  ],
};

// Gateways aren't included: each Gateway claims an Application Gateway for Containers frontend.
local editRole = kube._Object('rbac.authorization.k8s.io/v1', 'ClusterRole', 'syn-gateway-api-edit') {
  metadata+: {
    labels+: {
      'rbac.authorization.k8s.io/aggregate-to-admin': 'true',
      'rbac.authorization.k8s.io/aggregate-to-edit': 'true',
    },
  },
  rules: [
    {
      apiGroups: [ 'gateway.networking.k8s.io' ],
      resources: userResources,
      verbs: [ 'create', 'delete', 'deletecollection', 'patch', 'update' ],
    },
  ],
};

// Define outputs below
{
  '00_namespace': namespace,
  '10_gateway': gateway,
  '20_rbac': [ viewRole, editRole ],
}
