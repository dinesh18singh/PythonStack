# ECS Fargate + CodePipeline (CodeBuild + CodeConnections) Deployment

## What this deploys

- A new VPC with 2 public subnets (ALB, NAT Gateway) and 2 private subnets (ECS tasks)
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

## Notes

- The stack initially deploys a placeholder image (`public.ecr.aws/nginx/nginx:latest`) so the ECS service has something to run before your pipeline has pushed real images. The first successful pipeline run replaces it.
- The NAT Gateway incurs an hourly + data-processing cost. If you want to cut costs for a dev/test environment, you could move ECS tasks into the public subnets with `AssignPublicIp: ENABLED` and drop the NAT Gateway — ask if you'd like that variant.
- Update `TaskCpu`/`TaskMemory`/`DesiredCount` parameters to size the service for your workload.
- HTTPS isn't configured out of the box (listener is HTTP:80). Add an ACM certificate and an HTTPS listener on port 443 if you need TLS — happy to add that if useful.
