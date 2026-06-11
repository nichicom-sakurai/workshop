output "service_account_count" {
  description = "Number of service accounts in the referenced Google Cloud project."
  value       = length(data.google_service_accounts.current.accounts)
}

output "service_accounts" {
  description = "Non-secret metadata for each service account (account_id, email, display name, disabled state)."
  value = [
    for account in data.google_service_accounts.current.accounts : {
      account_id   = account.account_id
      email        = account.email
      display_name = account.display_name
      disabled     = account.disabled
    }
  ]
}
