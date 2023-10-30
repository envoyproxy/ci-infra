locals {
  asg_name = "${var.ami_prefix}_${var.pool_name}_pool"
}

data "aws_ami" "ci_image" {
  most_recent = true
  owners = [var.aws_account_id]

  filter {
    name = "name"
    values = ["${var.ami_prefix}-*"]
  }

  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_launch_template" "small_pool" {
  name_prefix = "${var.ami_prefix}_${var.pool_name}"
  image_id = data.aws_ami.ci_image.id
  instance_type = var.instance_types[0]

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size = var.disk_size_gb
      volume_type = var.disk_volume_type
      iops = var.disk_iops
      throughput = var.disk_throughput
      delete_on_termination = true
      encrypted = true
    }
  }

  iam_instance_profile {
    arn = aws_iam_instance_profile.asg_small_init_iam_instance_profile.arn
  }

  monitoring {
    enabled = true
  }

  instance_initiated_shutdown_behavior = "terminate"
  key_name = "envoy-shared2"
  metadata_options {
    http_endpoint = "enabled"
    http_tokens = "optional"
  }
  user_data = base64encode(templatefile("${path.module}/init.sh.tpl", {
    asg_name = local.asg_name
    pool_name = var.pool_name
    instance_profile_arn = aws_iam_instance_profile.asg_small_iam_instance_profile.arn
    role_name = aws_iam_role.asg_small_iam_role.name
    token_name = var.token_name
  }))
  vpc_security_group_ids = [aws_security_group.allow_ssh.id]
}

resource "aws_autoscaling_group" "small_pool" {
  name = local.asg_name

  min_size = var.idle_instances_count
  desired_capacity = var.idle_instances_count
  max_size         = 100
  protect_from_scale_in = true

  health_check_grace_period = 300
  health_check_type = "EC2"

  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.small_pool.id
        version = "$Latest"
      }

      dynamic "override" {
        for_each = toset(var.instance_types)
        content {
          instance_type = override.key
        }
      }
    }

    instances_distribution {
      on_demand_base_capacity = var.on_demand_instances_count
      on_demand_percentage_above_base_capacity = 0
      spot_allocation_strategy = "capacity-optimized"
    }
  }

  tags = [
    {
      key = "PoolName"
      value = var.pool_name
      propagate_at_launch = true
    }
  ]

  vpc_zone_identifier = data.aws_subnet_ids.default.ids
}
