# This uses azapi in order to avoid having to grant data plane permissions
resource "azapi_resource" "containers" {
  for_each = var.containers

  type = "Microsoft.Storage/storageAccounts/blobServices/containers@2022-09-01"
  body = jsonencode({
    properties = {
      metadata     = each.value.metadata
      publicAccess = each.value.public_access
    }
  })
  name      = each.value.name
  parent_id = "${azurerm_storage_account.this.id}/blobServices/default"

  dynamic "timeouts" {
    for_each = each.value.timeouts == null ? [] : [each.value.timeouts]
    content {
      create = timeouts.value.create
      delete = timeouts.value.delete
      read   = timeouts.value.read
      update = timeouts.value.update
    }
  }
}

# Enable role assignments for containers
resource "azurerm_role_assignment" "containers" {
  for_each = local.containers_role_assignments

  principal_id                           = each.value.role_assignment.principal_id
  scope                                  = azapi_resource.containers[each.value.container_key].id
  condition                              = each.value.role_assignment.condition
  condition_version                      = each.value.role_assignment.condition_version
  delegated_managed_identity_resource_id = each.value.role_assignment.delegated_managed_identity_resource_id
  role_definition_id                     = strcontains(lower(each.value.role_assignment.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? each.value.role_assignment.role_definition_id_or_name : null
  role_definition_name                   = strcontains(lower(each.value.role_assignment.role_definition_id_or_name), lower(local.role_definition_resource_substring)) ? null : each.value.role_assignment.role_definition_id_or_name
  skip_service_principal_aad_check       = each.value.role_assignment.skip_service_principal_aad_check
}

resource "time_sleep" "wait_for_rbac_before_container_operations" {
  count = length(var.role_assignments) > 0 && length(var.containers) > 0 ? 1 : 0

  create_duration  = var.wait_for_rbac_before_container_operations.create
  destroy_duration = var.wait_for_rbac_before_container_operations.destroy
  triggers = {
    role_assignments = jsonencode(var.role_assignments)
  }

  depends_on = [
    azurerm_role_assignment.storage_account
  ]
}
