@JsonAccess(serializable='always' deserializable='always')
global class S3AccountDTO {
  @AuraEnabled
  global String id;

  @AuraEnabled
  global String name;

  @AuraEnabled
  global String industry;

  @AuraEnabled
  global String phone;

  @AuraEnabled
  global String website;

  @AuraEnabled
  global List<S3ContactDTO> contacts;
}
