# Everything here is allowed and must not be flagged.

locals {
  # HTTPS to the name the certificate covers — the phase 0 end state.
  vm_url   = "https://${local.vehicle_manager_internal_fqdn}:3052/api/v1"
  aiws_url = "https://ai-webstudio42-internal.tec42.io:3042/api/v1"

  # A bare port is not a URL: step 0.6 still names TCP ports while it runs.
  tcp_port = 3050
  tls_port = 3052
}

resource "aws_ecs_task_definition" "example" {
  container_definitions = jsonencode([{
    # The container talks to itself.
    healthCheck = { command = ["CMD-SHELL", "curl -f http://localhost:3050/api/v1/health || exit 1"] }
  }])
}

resource "aws_lb_listener" "edge_redirect" {
  # The public ALB's edge hop, out of scope per phase 0 step 0.7.
  default_action {
    type = "redirect"
    redirect {
      protocol = "HTTPS"
      port     = "443"
      status_code = "HTTP_301"
    }
  }
}

# An allowed exception carries its reason on the line.
locals {
  legacy = "http://vehicle-manager-internal.tec42.io:3050/api/v1" # plaintext-ok: fixture for the escape hatch
}
