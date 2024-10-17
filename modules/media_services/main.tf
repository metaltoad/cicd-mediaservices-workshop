# Media Services module

resource "aws_media_package_channel" "channel" {
  channel_id = "workshop-channel"
  description = "Media Package Channel for Workshop"
  hls_ingest {
    ingest_endpoints {
      url = "https://d3hx2mfjmfgdc.cloudfront.net/v1/ads?duration=45"
    }
  }
}
resource "aws_medialive_input" "channel_input" {
  name = "workshop-channel-input"
  type = "https://d15an60oaeed9r.cloudfront.net/live_stream_v2/sports_reel_with_markers.m3u8"
}
resource "aws_medialive_channel" "channel" {
  name = "workshop-channel"
  channel_class = "STANDARD"
  input_specification {
    codec            = "AVC"
    maximum_bitrate  = "MAX_20_MBPS"
    input_resolution = "HD"
  }
  input_attachments {
    input_attachment_name = "CDN"
    input_id = aws_medialive_input.channel_input.id
  }

  destinations {
    id = "CDN"
    settings {
      url = aws_cloudfront_distribution.distribution.domain_name
    }
  }

  encoder_settings {
    timecode_config {
        source = "SYSTEMCLOCK"
    }
    audio_descriptions {
      audio_selector_name = "Sample name"
      name = "audio_1"
      audio_type_control = "FOLLOW_INPUT"
      language_code_control = "FOLLOW_INPUT"
      codec_settings {
        aac_settings {
          bitrate = 192000
          coding_mode = "CODING_MODE_2_0"
          sample_rate = 48000
        }
      }
    }
    video_descriptions {
      name = "video_1"
      codec_settings {
        h264_settings {
          profile = "HIGH"
          level   = "4.1"
        }
      }
    }
    output_groups {
      name = "HLS"
      output_group_settings {
        hls_group_settings {
          segment_length = 10
          destination {
            destination_ref_id = "CDN"
          }
        }
      }
    
      outputs {
        output_name ="CDN_output"
        output_settings {
          multiplex_output_settings {
            destination {
              destination_ref_id = "CDN"
            }
          }
          }
        }
      }
    }
}

  # Add more configuration as needed


resource "aws_cloudfront_distribution" "distribution" {
  enabled             = true
  default_root_object = "index.html"

  origin {
    domain_name = aws_media_package_origin_endpoint.hls_endpoint.url
    origin_id   = aws_media_package_origin_endpoint.hls_endpoint.id

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
    target_origin_id       = aws_media_package_origin_endpoint.hls_endpoint.id
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
            ["AWS/MediaLive", "NetworkIn", "ChannelId", aws_medialive_input.channel_input.id],
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
            ["AWS/MediaPackage", "EgressBytes", "ChannelId", aws_media_package_channel.channel.id]
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