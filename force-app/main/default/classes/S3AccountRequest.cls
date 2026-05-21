@JsonAccess(serializable='always' deserializable='always')
global class S3AccountRequest {
  @AuraEnabled
  global String accountName;

  @AuraEnabled
  global String s3ObjectPath;

  @AuraEnabled
  global String bucketOverride;

  @AuraEnabled
  global Boolean mockMode;
}
