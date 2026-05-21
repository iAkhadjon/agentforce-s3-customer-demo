@JsonAccess(serializable='always' deserializable='always')
global class S3ContactDTO {
  @AuraEnabled
  global String id;

  @AuraEnabled
  global String accountId;

  @AuraEnabled
  global String firstName;

  @AuraEnabled
  global String lastName;

  @AuraEnabled
  global String email;

  @AuraEnabled
  global String title;
}
