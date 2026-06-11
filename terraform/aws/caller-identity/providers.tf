# Provider configuration:
# provider block は特定の provider を設定します。このチュートリアルでは aws を設定します。
# provider とは、Terraform がリソースを作成・管理するために使用する plugin のことです。
#
# 1 つの設定に複数の provider block を書いて、異なる provider のリソースを管理できます。
# さらに、異なる provider を組み合わせて使うこともできます。
# 例えば AWS EC2 インスタンスの IP アドレスを Datadog のモニタリングリソースへ渡す、といった連携が可能です。
#
# 補足 (https://developer.hashicorp.com/terraform/language/providers/requirements より):
# - 役割分担: provider block は provider を「設定」する場所で、依存の「宣言」は terraform.tf の
#   required_providers block が担います。両方そろって初めて provider が使えます。
# - local name の一致: provider block 名 ("aws") は required_providers の local name と一致させます。
#   Terraform はこの local name とリソース type の接頭辞 (aws_caller_identity など) から、
#   どの provider を使うかを推論します。
# - 空の block: region や認証情報を書かない場合、環境変数 / AWS の共有設定 (~/.aws/*) から解決されます。
#   本サンプルは aws_caller_identity を読むだけなので、ここでは明示設定を持たせていません。
# - 同一 provider の複数設定: 例えばマルチリージョンのように同じ provider を複数構成したい場合は、
#   alias meta-argument で別名を付け、リソース側で provider = aws.<alias> と参照します。
provider "aws" {}
