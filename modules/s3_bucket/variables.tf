#------------------------------------------------------------------------------
# Variables for s3_bucket module
#------------------------------------------------------------------------------
variable "bucket_name" {
  description = "Existing S3 bucket name for storing configs"
  type        = string
}
