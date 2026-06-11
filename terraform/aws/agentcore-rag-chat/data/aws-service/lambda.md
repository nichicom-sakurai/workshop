# AWS Lambda

AWS Lambda runs code without provisioning or managing servers. You pay only for the compute time you consume.

## Key concepts

- **Function**: The unit of deployment. Supports runtimes such as Python, Node.js, Java, Go, and custom runtimes via container images.
- **Trigger / event source**: Services such as API Gateway, S3, SQS, EventBridge, and DynamoDB Streams invoke functions.
- **Handler**: The entry-point function that receives the event and context.
- **Concurrency**: The number of in-flight executions. Reserved and provisioned concurrency control scaling and cold starts.

## Limits to remember

- Maximum execution timeout is 15 minutes.
- Memory is configurable from 128 MB to 10,240 MB; CPU scales with memory.
- The deployment package is limited to 50 MB zipped (direct upload) or 250 MB unzipped; container images can be up to 10 GB.

## Typical use cases

- Event-driven processing (for example resizing images uploaded to S3).
- Lightweight REST or GraphQL backends behind API Gateway.
- Scheduled jobs via EventBridge rules.
