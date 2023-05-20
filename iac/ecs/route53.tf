resource "aws_route53_zone" "private" {
  name = "poc-observability.com"
  vpc {
    vpc_id = var.vpc_id
  }
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "poc-observability.com"
  type    = "A"

  alias {
    name                   = aws_lb.poc_open_source_observability.dns_name
    zone_id                = aws_lb.poc_open_source_observability.zone_id
    evaluate_target_health = true
  }

  depends_on = [aws_lb.poc_open_source_observability]
}

output "zone_id" {
  value       = aws_route53_zone.private.zone_id
  description = "The Hosted Zone ID"
}

output "name_servers" {
  value       = aws_route53_zone.private.name_servers
  description = "A list of name servers in associated delegation set"
}
