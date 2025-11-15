#------------------------------------------------------------------------------
# DynamoDB Table for Terraform locking
#------------------------------------------------------------------------------
data "aws_dynamodb_table" "existing" {
  name = var.table_name
}

resource "aws_dynamodb_table" "terraform_lock" {
  count        = data.aws_dynamodb_table.existing.id != "" ? 0 : 1
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  lifecycle {
    prevent_destroy = true
  }
}
