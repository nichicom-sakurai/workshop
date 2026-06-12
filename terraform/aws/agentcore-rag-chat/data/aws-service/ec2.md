# Amazon EC2 (Elastic Compute Cloud)

Amazon EC2 provides resizable virtual servers ("instances") in the AWS cloud.

## Key concepts

- **Instance types**: Combinations of CPU, memory, storage, and networking capacity (for example `t3.micro`, `m7g.large`, `c7i.xlarge`). General purpose, compute optimized, memory optimized, and accelerated families exist.
- **AMI (Amazon Machine Image)**: A template containing the OS and software used to launch an instance.
- **EBS volumes**: Network-attached block storage that persists independently of the instance lifecycle.
- **Security groups**: Stateful virtual firewalls that control inbound and outbound traffic at the instance level.
- **Key pairs**: SSH credentials used to connect to Linux instances.

## Pricing models

- **On-Demand**: Pay per second with no commitment.
- **Savings Plans / Reserved Instances**: Lower price in exchange for a 1- or 3-year usage commitment.
- **Spot Instances**: Up to 90% discount using spare capacity; can be interrupted with a two-minute notice.

## Common operations

- Launch an instance from an AMI into a subnet of a VPC.
- Attach an Elastic IP for a stable public address.
- Use Auto Scaling groups to add or remove instances based on demand.
