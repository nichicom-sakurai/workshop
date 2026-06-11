# Information Security Policy (excerpt)

Fictional policy used as sample document data for the RAG chat.

## Data classification

- **Public**: May be shared freely (for example marketing material).
- **Internal**: Default for business data; share only within the company.
- **Confidential**: Customer data and secrets; access on a need-to-know basis only.

## Credentials and secrets

- Never commit secrets to source control. Use the secrets manager or environment variables.
- Multi-factor authentication (MFA) is mandatory for all production access.
- API keys must be rotated at least every 90 days.

## Incident reporting

- Report suspected security incidents to security@example.com within one hour of discovery.
- Do not attempt to investigate or remediate production incidents alone; engage the on-call security responder.
