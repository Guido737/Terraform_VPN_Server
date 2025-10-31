#------------------------------------------------------------------------------
# Server-side encryption for existing S3 bucket
#------------------------------------------------------------------------------
resource "aws_s3_bucket_server_side_encryption_configuration" "vpn_configs_encryption" {
  bucket = var.bucket_name

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
