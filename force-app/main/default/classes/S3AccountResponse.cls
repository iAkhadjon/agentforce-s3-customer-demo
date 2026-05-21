@JsonAccess(serializable='always' deserializable='always')
global class S3AccountResponse {
  @AuraEnabled
  global Boolean success;

  @AuraEnabled
  global String message;

  @AuraEnabled
  global S3AccountDTO account;

  @AuraEnabled
  global List<S3AccountDTO> accounts;

  @AuraEnabled
  global List<S3ContactDTO> contacts;
}
