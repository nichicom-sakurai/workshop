# Provider configuration:
# region や認証情報は Terraform AWS provider の標準の仕組み
# （環境変数 / AWS shared config / profile など）から解決します。
# このサンプルでは provider block 内に secret や machine-local な値を書きません。
provider "aws" {}
