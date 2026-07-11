#!/usr/bin/env bash
set -euo pipefail
 
# ---- Fill these in for your setup ----
STACK_NAME="my-web-app"
PROJECT_NAME="my-web-app"
GITHUB_REPO="dinesh18singh/PythonStack"       # owner/repo
GITHUB_BRANCH="main"
CONTAINER_PORT="80"
REGION="${AWS_REGION:-us-east-1}"
# ---------------------------------------

aws cloudformation deploy \
  --template-file ecs-fargate-cicd.yaml \
  --stack-name my-web-app \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
      ProjectName=my-web-app \
      GitHubFullRepositoryId="${GITHUB_REPO}" \
      GitHubBranchName=main \
      ExistingCodeConnectionArn=arn:aws:codeconnections:ap-south-1:781321020517:connection/2b93553e-8f1c-46e4-868a-e166eea34ae1 \
      ContainerPort=80

echo "==> Stack deployed. Fetching outputs..."
CONNECTION_ARN=$(aws cloudformation describe-stacks \
  --stack-name "${STACK_NAME}" --region "${REGION}" \
  --query "Stacks[0].Outputs[?OutputKey=='CodeConnectionArn'].OutputValue" \
  --output text)
 
PIPELINE_NAME=$(aws cloudformation describe-stacks \
  --stack-name "${STACK_NAME}" --region "${REGION}" \
  --query "Stacks[0].Outputs[?OutputKey=='PipelineName'].OutputValue" \
  --output text)
 
APP_URL=$(aws cloudformation describe-stacks \
  --stack-name "${STACK_NAME}" --region "${REGION}" \
  --query "Stacks[0].Outputs[?OutputKey=='LoadBalancerURL'].OutputValue" \
  --output text)
 
echo "==> App URL (once first deploy succeeds): ${APP_URL}"
echo "==> Pipeline name: ${PIPELINE_NAME}"
 
CONNECTION_STATUS=$(aws codestar-connections get-connection \
  --connection-arn "${CONNECTION_ARN}" --region "${REGION}" \
  --query "Connection.ConnectionStatus" --output text)
 
if [[ "${CONNECTION_STATUS}" != "AVAILABLE" ]]; then
  echo ""
  echo "!! CodeConnection status is '${CONNECTION_STATUS}', not AVAILABLE."
  echo "!! Go authorize it once in the console before the pipeline can pull source:"
  echo "!! AWS Console -> Developer Tools -> Settings -> Connections -> ${CONNECTION_ARN}"
  echo "!! Click 'Update pending connection', then re-run this script or just start the pipeline manually:"
  echo "!!   aws codepipeline start-pipeline-execution --name ${PIPELINE_NAME} --region ${REGION}"
  exit 0
fi
 
echo "==> CodeConnection is AVAILABLE. Starting a pipeline execution..."
EXECUTION_ID=$(aws codepipeline start-pipeline-execution \
  --name "${PIPELINE_NAME}" --region "${REGION}" \
  --query "pipelineExecutionId" --output text)
 
echo "==> Pipeline execution started: ${EXECUTION_ID}"
echo "==> Watch progress with:"
echo "    aws codepipeline get-pipeline-execution --pipeline-name ${PIPELINE_NAME} --pipeline-execution-id ${EXECUTION_ID} --region ${REGION}"
echo "    (or in the console: CodePipeline -> ${PIPELINE_NAME})"
