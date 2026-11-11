locals {
  inventory = jsondecode(file("${path.module}/inventory.json"))
}

provider "cloudfoundry" {}

resource "btp_directory" "inventory" {
  for_each = local.inventory.directories

  name      = each.value.name
  parent_id = each.value.parent_id
  features  = each.value.features
}

resource "btp_subaccount" "inventory" {
  for_each = local.inventory.subaccounts

  name      = each.value.name
  subdomain = each.value.subdomain
  region    = each.value.region
  parent_id = (
    try(each.value.parent_directory, null) == null
    ? null
    : btp_directory.inventory[each.value.parent_directory].id
  )
  skip_auto_entitlement = try(each.value.skip_auto_entitlement, null)
  labels                = try(each.value.labels, null)
}

resource "btp_subaccount_entitlement" "inventory" {
  for_each = {
    for key, value in local.inventory.entitlements : key => value
    if key != "ewm-dev::APPLICATION_RUNTIME::MEMORY" && key != "ewm-dev::cloudfoundry::trial"
  }

  subaccount_id = each.value.subaccount_id
  service_name  = each.value.service_name
  plan_name     = each.value.plan_name
  amount        = try(each.value.amount, null)
}

resource "btp_subaccount_entitlement" "ewm_dev_runtime" {
  subaccount_id = local.inventory.entitlements["ewm-dev::APPLICATION_RUNTIME::MEMORY"].subaccount_id
  service_name  = local.inventory.entitlements["ewm-dev::APPLICATION_RUNTIME::MEMORY"].service_name
  plan_name     = local.inventory.entitlements["ewm-dev::APPLICATION_RUNTIME::MEMORY"].plan_name
  amount        = local.inventory.entitlements["ewm-dev::APPLICATION_RUNTIME::MEMORY"].amount

  depends_on = [
    btp_subaccount_entitlement.inventory["trial::APPLICATION_RUNTIME::MEMORY"],
  ]
}

resource "btp_subaccount_entitlement" "ewm_dev_cloudfoundry" {
  subaccount_id = local.inventory.entitlements["ewm-dev::cloudfoundry::trial"].subaccount_id
  service_name  = local.inventory.entitlements["ewm-dev::cloudfoundry::trial"].service_name
  plan_name     = local.inventory.entitlements["ewm-dev::cloudfoundry::trial"].plan_name
}

resource "btp_subaccount_environment_instance" "inventory" {
  for_each = {
    for key, value in local.inventory.environment_instances : key => value
    if key != "ewm-dev"
  }

  subaccount_id    = each.value.subaccount_id
  name             = each.value.name
  environment_type = each.value.environment_type
  service_name     = each.value.service_name
  plan_name        = each.value.plan_name
  landscape_label  = each.value.landscape_label
  parameters       = jsonencode(each.value.parameters)
}

resource "btp_subaccount_environment_instance" "ewm_dev" {
  subaccount_id    = local.inventory.environment_instances["ewm-dev"].subaccount_id
  name             = local.inventory.environment_instances["ewm-dev"].name
  environment_type = local.inventory.environment_instances["ewm-dev"].environment_type
  service_name     = local.inventory.environment_instances["ewm-dev"].service_name
  plan_name        = local.inventory.environment_instances["ewm-dev"].plan_name
  landscape_label  = local.inventory.environment_instances["ewm-dev"].landscape_label
  parameters       = jsonencode(local.inventory.environment_instances["ewm-dev"].parameters)

  depends_on = [
    btp_subaccount_entitlement.ewm_dev_runtime,
    btp_subaccount_entitlement.ewm_dev_cloudfoundry,
  ]
}

data "cloudfoundry_org" "ewm_dev" {
  name       = "ewm-dev"
  depends_on = [btp_subaccount_environment_instance.ewm_dev]
}

resource "btp_subaccount_service_instance" "inventory" {
  for_each = local.inventory.service_instances

  subaccount_id  = each.value.subaccount_id
  name           = each.value.name
  serviceplan_id = each.value.serviceplan_id
}

resource "btp_subaccount_subscription" "inventory" {
  for_each = local.inventory.subscriptions

  subaccount_id = each.value.subaccount_id
  app_name      = each.value.app_name
  plan_name     = each.value.plan_name
}

resource "cloudfoundry_space" "inventory" {
  for_each = {
    for key, value in local.inventory.cf_spaces : key => value
    if key != "ewm-dev"
  }

  name        = each.value.name
  org         = each.value.org
  allow_ssh   = each.value.allow_ssh
  labels      = length(each.value.labels) > 0 ? each.value.labels : null
  annotations = length(each.value.annotations) > 0 ? each.value.annotations : null
}

resource "cloudfoundry_space" "ewm_dev" {
  name        = local.inventory.cf_spaces["ewm-dev"].name
  org         = data.cloudfoundry_org.ewm_dev.id
  allow_ssh   = local.inventory.cf_spaces["ewm-dev"].allow_ssh
  labels      = length(local.inventory.cf_spaces["ewm-dev"].labels) > 0 ? local.inventory.cf_spaces["ewm-dev"].labels : null
  annotations = length(local.inventory.cf_spaces["ewm-dev"].annotations) > 0 ? local.inventory.cf_spaces["ewm-dev"].annotations : null

  depends_on = [cloudfoundry_org_quota.ewm_dev]
}

resource "cloudfoundry_org_role" "inventory" {
  for_each = local.inventory.cf_org_roles

  org  = each.value.org
  type = each.value.type
  user = each.value.user
}

resource "cloudfoundry_space_role" "inventory" {
  for_each = local.inventory.cf_space_roles

  space = each.value.space
  type  = each.value.type
  user  = each.value.user
}

resource "cloudfoundry_org_quota" "inventory" {
  for_each = {
    for key, value in local.inventory.cf_org_quotas : key => value
    if key != "ewm-dev"
  }

  name                     = each.value.name
  allow_paid_service_plans = each.value.allow_paid_service_plans
  instance_memory          = try(each.value.instance_memory, null)
  total_memory             = try(each.value.total_memory, null)
  total_app_instances      = try(each.value.total_app_instances, null)
  total_routes             = try(each.value.total_routes, null)
  total_services           = try(each.value.total_services, null)
  total_service_keys       = try(each.value.total_service_keys, null)
  total_private_domains    = try(each.value.total_private_domains, null)
  total_app_tasks          = try(each.value.total_app_tasks, null)
  total_route_ports        = try(each.value.total_route_ports, null)
  total_app_log_rate_limit = try(each.value.total_app_log_rate_limit, null)
  orgs                     = each.value.orgs
}

resource "cloudfoundry_org_quota" "ewm_dev" {
  name                     = local.inventory.cf_org_quotas["ewm-dev"].name
  allow_paid_service_plans = local.inventory.cf_org_quotas["ewm-dev"].allow_paid_service_plans
  instance_memory          = local.inventory.cf_org_quotas["ewm-dev"].instance_memory
  total_memory             = local.inventory.cf_org_quotas["ewm-dev"].total_memory
  total_app_instances      = local.inventory.cf_org_quotas["ewm-dev"].total_app_instances
  total_routes             = local.inventory.cf_org_quotas["ewm-dev"].total_routes
  total_services           = local.inventory.cf_org_quotas["ewm-dev"].total_services
  orgs                     = [data.cloudfoundry_org.ewm_dev.id]
}
