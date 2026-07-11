aws cloudformation deploy \
  --template-file ecs-fargate-cicd.yaml \
  --stack-name my-web-app \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
      ProjectName=my-web-app \
      GitHubFullRepositoryId=dinesh18singh/PythonStack \
      GitHubBranchName=main \
      ExistingCodeConnectionArn=arn:aws:codeconnections:ap-south-1:781321020517:connection/2b93553e-8f1c-46e4-868a-e166eea34ae1 \
      ContainerPort=80
