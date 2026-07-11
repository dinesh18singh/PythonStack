aws cloudformation deploy \
  --template-file ecs-fargate-cicd.yaml \
  --stack-name my-web-app \
  --capabilities CAPABILITY_NAMED_IAM \
  --parameter-overrides \
      ProjectName=my-web-app \
      GitHubFullRepositoryId=dinesh18singh/PythonStack \
      GitHubBranchName=main \
      ContainerPort=80
