resource "aws_iam_instance_profile" "test_profile" {
  name_prefix = "TestEnv-AppServer-${var.env_number}"
  role = aws_iam_role.role.name
}

resource "aws_iam_role" "role" {
  name_prefix = "AppServer-${var.env_number}"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "ec2.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

data "aws_iam_policy" "ssm_access" {
  arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "sto-readonly-role-policy-attach" {
  role       = "${aws_iam_role.role.name}"
  policy_arn = "${data.aws_iam_policy.ssm_access.arn}"
}