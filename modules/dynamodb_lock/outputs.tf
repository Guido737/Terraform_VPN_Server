#------------------------------------------------------------------------------
# Outputs for DynamoDB Lock Module
#------------------------------------------------------------------------------

output "table_name" {
  description = "Name of the DynamoDB lock table"
  value       = var.table_name
}
