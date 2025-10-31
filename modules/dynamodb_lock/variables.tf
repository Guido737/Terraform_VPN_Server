#------------------------------------------------------------------------------
# Variables for dynamodb_lock module
#------------------------------------------------------------------------------
variable "table_name" {
  description = "DynamoDB table name for Terraform locking"
  type        = string
}
