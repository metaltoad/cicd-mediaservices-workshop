import { App, Stack } from "aws-cdk-lib";
import { CodePipeline, CodePipelineSource, ManualApprovalStep, ShellStep } from "aws-cdk-lib/pipelines";
import { Effect, PolicyStatement } from "aws-cdk-lib/aws-iam";
import { BuildSpec } from "aws-cdk-lib/aws-codebuild";
import { createPreAndPostBuildActions } from "./resources/code-build";
import { MediaServicesStage } from "../media-services";
import { PIPELINE_PROD_MANUAL_APPROVAL } from "../workshop-stacks/config/pipeline";

/**
 * Stack to create a self mutating Pipeline(s) for deploying workflows.
 *
 * This creates CodeBuild, the adds the Stages required to deploy the CDK App.
 * It also adds pre and post hooks for stopping & starting the MediaLive channel.
 *
 * @see https://docs.aws.amazon.com/cdk/api/v2/docs/aws-cdk-lib.pipelines.CodePipeline.html
 */
export class PipelineStack extends Stack {
  constructor(app: App, private mediaStage: MediaServicesStage) {
    super(app, "workshop-pipeline-stack", {
      description: "Workshop pipeline stack (uksb-1tupboc33)",
      env: {
        region: process.env.CDK_DEFAULT_REGION,
        account: process.env.CDK_DEFAULT_ACCOUNT,
      },
    });
  }

  protected githubOwner = "metaltoad";
  protected githubRepo = "cicd-mediaservices-workshop";

  // Define the connection ARN (This should be the ARN of your existing CodeStar connection)
  // connectionArn = "arn:aws:codeconnections:us-east-1:593793053156:connection/0ce39d0d-884d-4915-bcd9-79978e8896dc";

  protected pipelines = this.createPipelines();

  createPipelines() {
    const pipeline = new CodePipeline(this, "pipeline", {
      selfMutation: true,
      synth: new ShellStep("Synth", {
        input: CodePipelineSource.connection(`${this.githubOwner}/${this.githubRepo}`, "task-1", {
          // eslint-disable-next-line @typescript-eslint/no-unsafe-assignment
          connectionArn: "arn:aws:codeconnections:us-east-1:593793053156:connection/0ce39d0d-884d-4915-bcd9-79978e8896dc", // Specify the existing connection ARN
        }),
        commands: [
          //"pwd",
          //'ls',
          //"aws cloudformation deploy --template-file ./cloudformation/remote_state.yaml --stack-name terraform-remote-state",
          //"curl -O https://releases.hashicorp.com/terraform/0.12.6/terraform_0.12.6_linux_amd64.zip",
          //"unzip terraform_0.12.6_linux_amd64.zip -d /usr/bin/",
          //"chmod +x /usr/bin/terraform",
          //"terraform init -upgrade -backend-config='bucket=terraform-remote-state-bucket-mthackaton2024' -backend-config='key=mediahackathon.tfstate' -backend-config='region=us-east-1' -backend=true",
          //"terraform plan",
          //"terraform apply -auto-approve",
          "npm ci", 
          "npm run build", 
          "npx cdk synth"],
      }),
      codeBuildDefaults: {
        partialBuildSpec: BuildSpec.fromObject({
          env: {
            shell: "bash",
          },
        }),
        rolePolicy: [
          new PolicyStatement({
            effect: Effect.ALLOW,
            actions: ["cloudformation:DescribeStacks", "medialive:DescribeChannel", "medialive:StopChannel", "medialive:StartChannel", "cloudformation:*"],
            resources: ["*"],
          }),
        ],
      },
    });

    if (PIPELINE_PROD_MANUAL_APPROVAL) {
      const manualApprovalWave = pipeline.addWave("prod-environment-catch");
      manualApprovalWave.addPre(new ManualApprovalStep("prod-environment-catch"));
    }
    pipeline.addStage(this.mediaStage, createPreAndPostBuildActions(this.mediaStage.stack.medialive.outputNames.channelName));

    return pipeline;
  }
}
