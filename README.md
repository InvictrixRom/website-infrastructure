# Wordpress AWS Infrastructure 

This is a terraform module based around https://aws.amazon.com/getting-started/projects/build-wordpress-website/

# Deploying

1. Create a `terraform.tfvars` file with content like this, replacing AWS Credentials where necessary:
```
access_key = "AAAAAAAAAAAAAAAAAAA"
secret_key = "z/zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz"
region = "us-west-1"
certificate_arn = "arn:aws:acm:us-west-1:000000000000:certificate/00000000-00000-0000-0000-000000000000"
```

2. Run `terraform apply` and it will create a state file, and show resources that will be created. Type `yes` when prompted and it will start applying. Note that the Amazon RDS database takes nearly 10 minutes to propagate, just be patient, you only need to do this once.

3. At the end of the apply process, you will see a line in green that says something along the lines of:
```
Outputs:

DNSName = wordpress-0000000000.us-west-1.elb.amazonaws.com
```

4. Point your DNS for the site to that DNS name with a CNAME record.

5. Once it's done, visit the site and restore a backup from the other wordpress site using Updraft.

6. All should work well and handle over a thousand requests per second.

## Extending this for the future

If you end up needing more bandwith for over 1000 simultaneous users, you can use CloudWatch alarms to trigger the Autoscaling Group to increase the number of instances to keep up with the traffic coming in seamlessly.