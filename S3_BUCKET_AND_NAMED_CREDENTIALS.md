# S3 Bucket and Salesforce Named Credential Setup

Use this guide to create the AWS S3 access required by the `AWS_S3_Demo` Salesforce Named Credential.

## 1. Create or Prepare the S3 Bucket

Create an S3 bucket in AWS.

Example bucket name:

```text
salesforce-agentforce-s3-demo
```

Recommended region:

```text
ap-northeast-2
```

Upload the customer data files expected by the Apex action:

```text
accounts.json
account.json
```

The Apex action reads `/accounts.json` first and falls back to `/account.json`.

For a quick public connectivity check, this example URL points to the fallback file:

```text
https://salesforce-agentforce-s3-demo.s3.ap-northeast-2.amazonaws.com/account.json
```

## 2. Login to AWS Console

Open:

```text
https://console.aws.amazon.com/
```

Go to:

```text
IAM (Identity and Access Management)
```

Search for:

```text
IAM
```

in the AWS search bar.

## 3. Create IAM User

Navigate:

```text
IAM -> Users -> Create User
```

Example user name:

```text
salesforce-s3-user
```

Select:

```text
Provide user access to the AWS Management Console = unchecked
```

You only need programmatic/API access.

Click:

```text
Next
```

## 4. Assign Permissions

Choose:

```text
Attach policies directly
```

For temporary demo/public bucket access you can use:

```text
AmazonS3FullAccess
```

Recommended safer option:

Create a custom policy limited to one bucket.

Example custom policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3BucketAccess",
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::salesforce-agentforce-s3-demo",
        "arn:aws:s3:::salesforce-agentforce-s3-demo/*"
      ]
    }
  ]
}
```

Click:

```text
Next -> Create User
```

## 5. Create Access Key

Open the new user:

```text
salesforce-s3-user
```

Go to:

```text
Security credentials
```

Scroll to:

```text
Access keys
```

Click:

```text
Create access key
```

Choose:

```text
Third-party service
```

or:

```text
Application running outside AWS
```

Click:

```text
Next
```

Optional description:

```text
Salesforce Agentforce S3 Integration
```

Click:

```text
Create access key
```

## 6. Copy Access Key and Secret

AWS will display:

```text
Access Key ID
Secret Access Key
```

Example:

```text
Access Key ID:
AKIAIOSFODNN7EXAMPLE

Secret Access Key:
wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

Important:

- Copy the secret immediately.
- AWS only shows the Secret Access Key once.
- Store the key pair securely.
- Do not commit AWS keys to source control.

## 7. Configure Salesforce External Credential

In Salesforce, go to:

```text
Setup -> Named Credentials -> External Credentials
```

Create or update the `AWS_S3_Demo` External Credential principal.

Use:

```text
Authentication Protocol: AWS Signature Version 4
Access Key: AWS Access Key ID
Secret: AWS Secret Access Key
Service: s3
Region: ap-northeast-2
```

Salesforce stores the secret value in the org. It is not stored in this Salesforce DX source project.

## 8. Configure Salesforce Named Credential

In Salesforce, go to:

```text
Setup -> Named Credentials -> Named Credentials
```

Create or verify the `AWS_S3_Demo` Named Credential.

Use:

```text
Label: AWS S3 Demo
Name: AWS_S3_Demo
URL: https://salesforce-agentforce-s3-demo.s3.ap-northeast-2.amazonaws.com
External Credential: AWS_S3_Demo
Generate Authorization Header: enabled
Callout Status: Enabled
```

If you deploy the metadata from this repository, these Named Credential settings are already defined in source. You still need to configure the External Credential principal secret in the target org.

## 9. Verify Named Credential Metadata

Before deploying, replace the placeholder AWS account ID in:

```text
force-app/main/default/externalCredentials/AWS_S3_Demo.externalCredential-meta.xml
```

Replace:

```xml
<parameterValue>testvalue</parameterValue>
```

with your own 12-digit AWS account ID.

If your bucket name or region differs from the example, update the URL in:

```text
force-app/main/default/namedCredentials/AWS_S3_Demo.namedCredential-meta.xml
```

## 10. Verify Connectivity

Test URL:

```text
https://salesforce-agentforce-s3-demo.s3.ap-northeast-2.amazonaws.com/account.json
```

If the object is public, the browser should open JSON.

If the bucket only allows signed AWS requests, the browser may show:

```text
AccessDenied
```

Salesforce Named Credential requests should still work correctly when the External Credential principal has valid AWS credentials and the IAM policy permits access.

## 11. Recommended Security Cleanup After Demo

After testing:

- Delete the access key.
- Disable the IAM user.
- Remove public bucket access.
- Replace broad permissions with a least-privilege IAM policy.

Navigate:

```text
IAM -> Users -> salesforce-s3-user -> Security credentials
```

Then:

```text
Deactivate
```

or:

```text
Delete Access Key
```
