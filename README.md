# ECS Fargate + CodePipeline (CodeBuild + CodeConnections) Deployment

## What this deploys

- A new VPC with 2 public subnets shared by the ALB and the ECS Fargate tasks (no NAT Gateway)
- An Application Load Balancer routing to an ECS Fargate service
- An ECR repository for your container image
- A CodePipeline with three stages:
  1. **Source** — pulls code from GitHub using an **AWS CodeConnection** (CodeStar Connections)
  2. **Build** — CodeBuild builds a Docker image and pushes it to ECR
  3. **Deploy** — updates the ECS service with the new image

## Files

- `ecs-fargate-cicd.yaml` — the CloudFormation template
- `buildspec.yml` — sample buildspec; **copy this to the root of your GitHub repo**
- Your repo also needs a `Dockerfile` at the root that builds and serves your website on the port you set as `ContainerPort` (default `80`)

## Deploy steps

### 1. Create the stack

```bash
aws cloudformation deploy \
  --template-file ecs-fargate-cicd.yaml \
  --stack-name my-web-app \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
      ProjectName=my-web-app \
      GitHubFullRepositoryId=your-org/your-repo \
      GitHubBranchName=main \
      ContainerPort=80
```

If you already have an authorized CodeConnection, pass its ARN instead of letting the template create one:

```bash
  --parameter-overrides ExistingCodeConnectionArn=arn:aws:codeconnections:...
```

### 2. Authorize the CodeConnection (first time only)

If the template created a new connection, it starts in `PENDING` status — CloudFormation cannot complete GitHub OAuth for you. After the stack finishes:

1. Go to **AWS Console → Developer Tools → Settings → Connections**
2. Find the connection (named `<ProjectName>-github-connection`)
3. Click **Update pending connection**, authorize AWS to access your GitHub account/org, and select the repo

Once authorized, re-run the pipeline (or it will trigger automatically on the next push).

### 3. Add `buildspec.yml` and a `Dockerfile` to your repo

Commit `buildspec.yml` (provided here) to the repo root, along with a `Dockerfile` for your website. Push to the branch you configured (`main` by default) — this triggers the pipeline.

### 4. Get the app URL

```bash
aws cloudformation describe-stacks \
  --stack-name my-web-app \
  --query "Stacks[0].Outputs[?OutputKey=='LoadBalancerURL'].OutputValue" \
  --output text
```

## Using extra credentials in CodeBuild (e.g. Docker Hub, npm, etc.)

CodeBuild already gets ECR push/pull access automatically via its IAM role
(`ecr:GetAuthorizationToken` + `docker login`) — no extra setup needed for
that. If your build needs *other* credentials — e.g. Docker Hub login to
avoid anonymous pull rate limits on your base image, an npm registry
token, etc — don't hardcode them. Store them in Secrets Manager and pass
the secret's ARN in:

```bash
  --parameter-overrides ExtraBuildCredentialsSecretArn=arn:aws:secretsmanager:region:account:secret:my-creds-xxxxxx
```

The secret should be a JSON object, e.g.:

```json
{ "username": "mydockerhubuser", "password": "mydockerhubtoken" }
```

When this parameter is set, the template:

- Grants the CodeBuild role `secretsmanager:GetSecretValue` on that one secret (least privilege — nothing else changes)
- Injects `DOCKERHUB_USERNAME` and `DOCKERHUB_PASSWORD` into the CodeBuild environment as `SECRETS_MANAGER`-type variables (CodeBuild resolves these at build start; they're never stored in the environment definition or logs)
- `buildspec.yml` uses them to `docker login` to Docker Hub before building, if present

To add a *different* secret (npm token, etc.), reuse the same `ExtraBuildCredentialsSecretArn` pattern — either add more keys to the same JSON secret and reference them with `${ExtraBuildCredentialsSecretArn}:keyname`, or duplicate the pattern with a second parameter/secret ARN.

## ARNs available as stack Outputs

The stack now exposes these ARNs (`aws cloudformation describe-stacks --stack-name <name> --query Stacks[0].Outputs`):

| Output | What it is |
|---|---|
| `CodeBuildProjectArn` | The CodeBuild project |
| `CodeBuildServiceRoleArn` | Role CodeBuild assumes to build/push |
| `CodePipelineServiceRoleArn` | Role CodePipeline assumes to orchestrate |
| `ECSTaskExecutionRoleArn` | Role ECS uses to pull images / write logs |
| `ECSTaskRoleArn` | Role your app container runs as |
| `PipelineArn` | The CodePipeline |
| `CodeConnectionArn` | The GitHub connection (see authorization step above) |

## Notes

- The stack initially deploys a placeholder image (`public.ecr.aws/nginx/nginx:latest`) so the ECS service has something to run before your pipeline has pushed real images. The first successful pipeline run replaces it.
- ECS tasks run in the public subnets with a public IP assigned (no NAT Gateway, so no NAT hourly/data-processing cost). They're still locked down at the network layer: the `ECSSecurityGroup` only allows inbound traffic on `ContainerPort` from the `ALBSecurityGroup` — nothing else, including the internet, can reach the tasks directly even though they have public IPs. If you later want tasks fully isolated from the internet at the routing layer too, reintroduce private subnets + a NAT Gateway (or NAT instance, or VPC endpoints for ECR/S3/CloudWatch Logs to avoid needing a NAT at all) — happy to add that back if needed.
- Update `TaskCpu`/`TaskMemory`/`DesiredCount` parameters to size the service for your workload.
- HTTPS isn't configured out of the box (listener is HTTP:80). Add an ACM certificate and an HTTPS listener on port 443 if you need TLS — happy to add that if useful.
