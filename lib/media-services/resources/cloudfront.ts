import { Aws, Duration, Fn } from "aws-cdk-lib";
import {
  AllowedMethods,
  CachePolicy,
  Distribution,
  OriginProtocolPolicy,
  OriginRequestCookieBehavior,
  OriginRequestHeaderBehavior,
  OriginRequestPolicy,
  OriginRequestQueryStringBehavior,
  OriginSslPolicy,
  ResponseHeadersPolicy,
  ViewerProtocolPolicy,
} from "aws-cdk-lib/aws-cloudfront";
import { HttpOrigin } from "aws-cdk-lib/aws-cloudfront-origins";
import { Secret } from "aws-cdk-lib/aws-secretsmanager";
import { Construct } from "constructs";
import { getDomainFromEmtEndpointUrl } from "../helpers/url-processing";

interface ICreateMediaCdn {
  emtOriginUrl: string;
  empOriginUrl: string;
  cdnAuthorization: Secret;
}

const errorResponse = [400, 403, 404, 405, 414, 416, 500, 501, 502, 503, 504];
const errorDuration = Duration.seconds(1);

/**
 * Construct to build a CloudFront Distribution.
 *
 * @see https://docs.aws.amazon.com/cdk/api/v2/docs/aws-cdk-lib.aws_cloudfront.Distribution.html
 */
export class Cdn extends Construct {
  constructor(scope: Construct, private props: ICreateMediaCdn) {
    super(scope, "cdn");
  }

  private myOriginRequestPolicyEMT = new OriginRequestPolicy(this, "OriginRequestPolicyEMT", {
    comment: Aws.STACK_NAME + "OriginRequest Policy EMT",
    cookieBehavior: OriginRequestCookieBehavior.none(),
    headerBehavior: OriginRequestHeaderBehavior.allowList(
      "X-Forwarded-For",
      "CloudFront-Viewer-Country",
      "User-Agent",
      "Access-Control-Request-Headers",
      "Access-Control-Request-Method",
      "Host",
    ),
    queryStringBehavior: OriginRequestQueryStringBehavior.allowList("aws.sessionId", "m"),
  });

  private myResponseHeadersPolicy = new ResponseHeadersPolicy(this, "ResponseHeadersPolicy", {
    responseHeadersPolicyName: Aws.STACK_NAME + "-ResponsePolicy",
    comment: "ResponseHeaders Policy for CORS",
    corsBehavior: {
      accessControlAllowCredentials: false,
      accessControlAllowHeaders: ["*"],
      accessControlAllowMethods: ["GET", "HEAD", "OPTIONS", "POST"],
      accessControlAllowOrigins: ["*"],
      accessControlMaxAge: Duration.seconds(600),
      originOverride: true,
    },
  });

  //Creating MediaTailor, MediaPackage with green header to be sent to the MediaPackage origin
  private mediaPackageOrigin = new HttpOrigin(`${Fn.select(2, Fn.split("/", this.props.empOriginUrl))}`, {
    customHeaders: {
      "X-MediaPackage-CDNIdentifier": this.props.cdnAuthorization.secretValueFromJson("MediaPackageCDNIdentifier").unsafeUnwrap().toString(),
    },
    originSslProtocols: [OriginSslPolicy.TLS_V1_2],
    protocolPolicy: OriginProtocolPolicy.HTTPS_ONLY,
  });

  private mediaTailorOrigin = new HttpOrigin(`${getDomainFromEmtEndpointUrl(this.props.emtOriginUrl)}`, {
    customHeaders: {
      "X-MediaPackage-CDNIdentifier": this.props.cdnAuthorization.secretValueFromJson("MediaPackageCDNIdentifier").unsafeUnwrap().toString(),
    },
    originSslProtocols: [OriginSslPolicy.TLS_V1_2],
    protocolPolicy: OriginProtocolPolicy.HTTPS_ONLY,
  });

  public distribution = new Distribution(this, "cdn", {
    errorResponses: errorResponse.map((errorCode) => {
      return {
        httpStatus: errorCode,
        ttl: errorDuration,
      };
    }),
    defaultBehavior: {
      origin: new HttpOrigin(`ads.mediatailor.${Aws.REGION}.amazonaws.com`, {
        originSslProtocols: [OriginSslPolicy.TLS_V1_2],
        protocolPolicy: OriginProtocolPolicy.HTTPS_ONLY,
      }),
      cachePolicy: CachePolicy.CACHING_OPTIMIZED,
      allowedMethods: AllowedMethods.ALLOW_GET_HEAD,
      viewerProtocolPolicy: ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
      responseHeadersPolicy: this.myResponseHeadersPolicy,
    },
    additionalBehaviors: {
      "/v1/session/*": {
        origin: this.mediaTailorOrigin,
        cachePolicy: CachePolicy.CACHING_DISABLED,
        allowedMethods: AllowedMethods.ALLOW_ALL,
        viewerProtocolPolicy: ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
        responseHeadersPolicy: ResponseHeadersPolicy.CORS_ALLOW_ALL_ORIGINS_WITH_PREFLIGHT,
      },
      "/v1/master/*": {
        origin: this.mediaTailorOrigin,
        cachePolicy: CachePolicy.CACHING_DISABLED,
        allowedMethods: AllowedMethods.ALLOW_GET_HEAD,
        originRequestPolicy: this.myOriginRequestPolicyEMT,
        viewerProtocolPolicy: ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
        responseHeadersPolicy: this.myResponseHeadersPolicy,
      },
      "/out/*": {
        origin: this.mediaPackageOrigin,
        originRequestPolicy: OriginRequestPolicy.ALL_VIEWER,
        cachePolicy: CachePolicy.ELEMENTAL_MEDIA_PACKAGE,
        allowedMethods: AllowedMethods.ALLOW_GET_HEAD,
        viewerProtocolPolicy: ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
        responseHeadersPolicy: this.myResponseHeadersPolicy,
      },
      "/v1/*": {
        origin: this.mediaTailorOrigin,
        cachePolicy: CachePolicy.CACHING_DISABLED,
        allowedMethods: AllowedMethods.ALLOW_GET_HEAD,
        originRequestPolicy: this.myOriginRequestPolicyEMT,
        viewerProtocolPolicy: ViewerProtocolPolicy.REDIRECT_TO_HTTPS,
        responseHeadersPolicy: this.myResponseHeadersPolicy,
      },
    },
  });
}
