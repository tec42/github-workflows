locals {
  # 1 — the internal name over plain HTTP
  a = "http://vehicle-manager-internal.tec42.io:3050/api/v1"
  # 2 — the raw NLB name
  b = "http://tec42-internal-nlb-production-0123.elb.eu-central-1.amazonaws.com:3010/api/v1"
  # 3 — an interpolation that resolves to the NLB
  c = "http://${local.nlb_internal_dns_name}:3020/api/v1"
}
