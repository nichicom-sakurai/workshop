# Output values:
# output block は、設定や data source から得た値を「出力値」として公開します。
# root module では terraform apply 後に CLI に表示され、terraform output コマンドで後から再取得できます。
# child module では、親から module.<NAME>.<OUTPUT> として参照できます。
#
# 構文: output "<NAME>" { value = <EXPRESSION> [description = ...] [sensitive = ...] }
# - NAME = "account_id" など: 出力値の名前です (module 内で一意)。terraform output <NAME> で個別取得できます。
# - value: 公開する式です。本サンプルでは main.tf の data source の属性を参照しています
#   (例: data.aws_caller_identity.current.account_id)。
#
# 補足 (https://developer.hashicorp.com/terraform/language/values/outputs より):
# - description: 人間向けの説明で、terraform output や plan の表示に使われます。
# - sensitive: true にすると CLI 出力で値がマスクされます。ただし state file には平文で保存される点に注意。
#   本サンプルの account_id / arn / user_id は機密ではないため設定していません。
# - 評価タイミング: output は参照先 (ここでは main.tf の data source) が確定した後に評価されます。
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
