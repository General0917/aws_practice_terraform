data "aws_iam_policy_document" "allow_describe_regions" {
    statement {
      effect = "Allow"
      actions = ["ec2:DescribeRegions"] # リージョン一覧を取得する
      resources = ["*"]
    }
}

resource "aws_iam_policy" "example" {
  name = "example"
  policy = data.aws_iam_policy_document.allow_describe_regions.json
}