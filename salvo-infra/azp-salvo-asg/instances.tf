# This file defines resources needed to deploy an Auto Scaling Group of Salvo
# Control VMs.

locals {
  asg_name = "${var.ami_prefix}_${var.azp_pool_name}_pool"
}

data "aws_ami" "azp_ci_image" {
  most_recent = true
  owners      = [var.aws_account_id]

  filter {
    name   = "name"
    values = ["${var.ami_prefix}-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_launch_template" "salvo_pool" {
  name_prefix   = "${var.ami_prefix}_${var.azp_pool_name}"
  image_id      = data.aws_ami.azp_ci_image.id
  instance_type = var.instance_types[0]

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size           = var.disk_size_gb
      volume_type           = "gp2"
      delete_on_termination = true
      encrypted             = true
    }
  }

  iam_instance_profile {
    arn = aws_iam_instance_profile.asg_salvo_init_iam_instance_profile.arn
  }

  monitoring {
    enabled = true
  }

  instance_initiated_shutdown_behavior = "terminate"
  key_name                             = "envoy-shared2"
  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "optional"
  }
  user_data = base64encode(templatefile("${path.module}/init.sh.tpl", {
    asg_name             = local.asg_name
    azp_pool_name        = var.azp_pool_name
    instance_profile_arn = aws_iam_instance_profile.asg_salvo_iam_instance_profile.arn
    role_name            = aws_iam_role.asg_salvo_iam_role.name
  }))
  vpc_security_group_ids = ["${var.salvo_control_vm_security_group.id}"]
}

resource "aws_autoscaling_group" "salvo_pool" {
  name = local.asg_name

  min_size         = var.idle_instances_count
  desired_capacity = var.idle_instances_count
  max_size         = 2

  health_check_grace_period = 300
  health_check_type         = "EC2"

  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.salvo_pool.id
        version            = "$Latest"
      }

      dynamic "override" {
        for_each = toset(var.instance_types)
        content {
          instance_type = override.key
        }
      }
    }

    instances_distribution {
      on_demand_base_capacity                  = var.on_demand_instances_count
      on_demand_percentage_above_base_capacity = 0
      spot_allocation_strategy                 = "capacity-optimized"
    }
  }

  tag {
      key                 = "PoolName"
      value               = var.azp_pool_name
      propagate_at_launch = true
  }

  vpc_zone_identifier = ["${var.salvo_control_vm_subnet.id}"]
}
