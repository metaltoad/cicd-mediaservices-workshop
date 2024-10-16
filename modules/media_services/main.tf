# Media Services module

resource "aws_mediapackage_channel" "channel" {
  channel_id = "workshop-channel"
  description = "Media Package Channel for Workshop"
}

resource "aws_mediapackage_origin_endpoint" "hls_endpoint" {
  channel_id = aws_mediapackage_channel.channel.id
  id         = "${aws_mediapackage_channel.channel.channel_id}-hls"

  hls_package {
    segment_duration_seconds = 6
    playlist_window_seconds  = 60
  }
}

resource "aws_medialive_channel" "channel" {
  name = "workshop-channel"

  input_specification {
    codec            = "AVC"
    maximum_bitrate  = "MAX_20_MBPS"
    resolution       = "HD"
  }

  channel_class = "STANDARD"

  # Add more configuration as needed
}

resource "aws_cloudfront_distribution" "distribution" {
  enabled             = true
  default_root_object = "index.html"

  origin {
    domain_name = aws_mediapackage_origin_endpoint.hls_endpoint.url
    origin_id   = aws_mediapackage_origin_endpoint.hls_endpoint.id

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = aws_mediapackage_origin_endpoint.hls_endpoint.id
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_cloudwatch_dashboard" "media_dashboard" {
  dashboard_name = "MediaServicesDashboard"
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/MediaLive", "NetworkIn", "ChannelId", aws_medialive_channel.channel.id],
            [".", "NetworkOut", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          title   = "MediaLive Network I/O"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/MediaPackage", "EgressBytes", "ChannelId", aws_mediapackage_channel.channel.id]
          ]
          view    = "timeSeries"
          stacked = false
          title   = "MediaPackage Egress Bytes"
        }
      }
    ]
  })
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.distribution.domain_name
}

output "hls_endpoint_url" {
  value = "https://${aws_cloudfront_distribution.distribution.domain_name}/${aws_mediapackage_origin_endpoint.hls_endpoint.id}"
}