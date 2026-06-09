# Data source:
# data block は外部システムから情報を読み取る (read-only の) クエリです。
# リソースを作成・更新・削除せず、既存の情報を取得して設定の中で参照できるようにします。
# aws_caller_identity は、現在 Terraform が使っている認証情報の
# アカウント ID / IAM プリンシパルの ARN / ユーザー ID を返します。
#
# 構文: data "<TYPE>" "<NAME>" { <arguments> }
# - TYPE = "aws_caller_identity": provider が提供する data source の種類です。
# - NAME = "current": module 内で参照するための local name です (同じ TYPE 内で一意)。
# - {} が空なのは、この data source が引数を必要としないためです。
#
# 補足 (https://developer.hashicorp.com/terraform/language/data-sources より):
# - resource との違い: resource は管理対象 (作成・変更・削除) ですが、data source は読み取り専用です。
# - 参照方法: data.<TYPE>.<NAME>.<ATTRIBUTE> でエクスポートされた属性を参照します。
#   実際の参照例は outputs.tf を参照してください (例: data.aws_caller_identity.current.account_id)。
# - 読み取り時点: 通常は plan 中に読み取られますが、引数が未確定なリソース属性に依存する場合は
#   apply まで遅延されます。本サンプルは引数がないため plan 中に読み取られます。
data "aws_caller_identity" "current" {}
