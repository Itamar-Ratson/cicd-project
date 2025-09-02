locals {
  ack_controllers = ["ec2", "ecr", "s3", "dynamodb", "sqs"]
}

resource "aws_iam_role" "ack_controller" {
  for_each = toset(local.ack_controllers)
  name     = "ack-${each.key}-controller"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${replace(var.oidc_provider_arn, "/^(.*provider/)/", "")}:sub" = "system:serviceaccount:ack-system:ack-${each.key}-controller"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ack_policies" {
  for_each   = toset(local.ack_controllers)
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
  role       = aws_iam_role.ack_controller[each.key].name
}

resource "helm_release" "ack_controllers" {
  for_each = toset(local.ack_controllers)
  
  name             = "ack-${each.key}-controller"
  repository       = "oci://public.ecr.aws/aws-controllers-k8s"
  chart            = "${each.key}-chart"
  namespace        = "ack-system"
  create_namespace = true
  version          = "1.0.0"
  
  set {
    name  = "aws.region"
    value = "eu-north-1"
  }
  
  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.ack_controller[each.key].arn
  }
}
