resource "aws_kms_key" "sqs-key" {
  description         = "Customer managed key for SQS"
  enable_key_rotation = true
}

resource "aws_kms_alias" "sqs-key-alias" {
  name          = "alias/ugt/sqs"
  target_key_id = aws_kms_key.sqs-key.key_id
}

data "aws_iam_policy_document" "sqs-kms-key-policy-document" {
  statement {
    effect = "Allow"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:GenerateDataKey",
      "kms:GenerateDataKeyWithoutPlaintext",
      "kms:GenerateDataKeyPairWithoutPlaintext",
      "kms:GenerateDataKeyPair"
    ]

    resources = [
      aws_kms_key.sqs-key.arn
    ]
  }
}

resource "aws_iam_policy" "sqs-kms-key-policy" {
  name   = "sqs-kms-key-policy"
  path   = "/c/"
  policy = data.aws_iam_policy_document.sqs-kms-key-policy-document.json
}