provider "aws" {
  profile = "${var.aws_profile}"
  region = "${var.aws_region}"
}

resource "aws_cloudwatch_log_group" "lambda-log-group" {
  name = "UpdateCloudflareIps"

}

resource "aws_iam_role" "iam_for_lambda" {

  name = "lambda-cloudflare-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_policy" "policy" {
  name = "lambda-cloudflare-policy"

  description = "Allows cloudflare ip updating lambda to change security groups"
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
      ],
      "Resource": [
          "arn:aws:logs:*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
          "iam:GetRolePolicy",
          "iam:ListGroupPolicies",
          "ec2:DescribeSecurityGroups",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress"
      ],
      "Resource": [
          "*"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "policy" {

  role = "${aws_iam_role.iam_for_lambda.id}"
  policy_arn = "${aws_iam_policy.policy.arn}"
}

data "archive_file" "lambda_zip" {

  type = "zip"
  source_dir = "${path.module}/script/"
  output_path = "${path.module}/lambda.zip"
}

resource "aws_lambda_function" "update-ips" {

  function_name = "UpdateCloudflareIps"
  filename = "${path.module}/lambda.zip"
  source_code_hash = "${data.archive_file.lambda_zip.output_base64sha256}"
  handler = "cloudflare-security-group.lambda_handler"
  role = "${aws_iam_role.iam_for_lambda.arn}"
  runtime = "python3.6"
  timeout = 60
  environment {
    variables = {
      SECURITY_GROUP_ID = "${var.security_group_id}"
    }
  }
}

