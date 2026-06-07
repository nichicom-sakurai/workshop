output "account_id" {
  description = "AWS account ID for the credentials used by this Terraform run."
  value       = data.aws_caller_identity.current.account_id
}

output "caller_arn" {
  description = "ARN for the IAM principal used by this Terraform run."
  value       = data.aws_caller_identity.current.arn
}

output "caller_user_id" {
  description = "Unique user ID for the IAM principal used by this Terraform run."
  value       = data.aws_caller_identity.current.user_id
}
