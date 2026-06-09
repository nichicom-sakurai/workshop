# Bucket name:
# S3 general purpose bucket names are globally unique. This learning sample
# combines a human-readable prefix with the current account ID and region to
# reduce accidental collisions while keeping the name predictable.
locals {
  bucket_name = "${var.bucket_prefix}-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.region}"
}
