#------------------------------------------------------------------------------
# DynamoDB Table for Terraform locking
#------------------------------------------------------------------------------
resource "aws_dynamodb_table" "terraform_lock" {
  name         = "terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [name]
  }

  attribute {
    name = "LockID"
    type = "S"
  }
}

