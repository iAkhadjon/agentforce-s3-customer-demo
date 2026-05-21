global with sharing class S3AccountAgentAction {
  private static final String NAMED_CREDENTIAL = 'callout:AWS_S3_Demo';
  private static final String DEFAULT_OBJECT_PATH = '/accounts.json';
  private static final String LEGACY_OBJECT_PATH = '/account.json';
  private static final Integer TIMEOUT_MS = 20000;

  @InvocableMethod(
    label='Get Account Data From S3'
    description='Retrieves account and contact data from AWS S3 bucket.'
    callout=true
  )
  global static List<S3AccountActionResponse> getAccountData(
    List<S3AccountActionRequest> requests
  ) {
    List<S3AccountActionResponse> responses = new List<S3AccountActionResponse>();

    if (requests == null || requests.isEmpty()) {
      responses.add(buildActionResponse(fetchAccountData(null)));
      return responses;
    }

    for (S3AccountActionRequest request : requests) {
      S3AccountRequest config = request == null ? null : request.request;
      responses.add(buildActionResponse(fetchAccountData(config)));
    }

    return responses;
  }

  @AuraEnabled
  global static S3AccountResponse lookupAccounts(String accountName) {
    S3AccountRequest request = new S3AccountRequest();
    request.accountName = accountName;
    return fetchAccountData(request);
  }

  private static S3AccountActionResponse buildActionResponse(
    S3AccountResponse accountData
  ) {
    S3AccountActionResponse response = new S3AccountActionResponse();
    response.accountData = accountData;
    return response;
  }

  @TestVisible
  private static S3AccountResponse fetchAccountData(S3AccountRequest config) {
    if (config == null) {
      return buildInitialResponse();
    }

    String requestedAccountName = normalizeSearchTerm(
      config.accountName
    );

    if (String.isBlank(requestedAccountName)) {
      return buildErrorResponse(
        'Please fill the form and submit an Account Name.'
      );
    }

    if (config.mockMode == true) {
      return buildFilteredResponse(buildMockAccounts(), requestedAccountName);
    }

    try {
      HttpResponse response = sendAccountRequest(config);
      Integer statusCode = response.getStatusCode();

      if (statusCode < 200 || statusCode >= 300) {
        return buildErrorResponse(
          'AWS S3 returned HTTP ' +
            statusCode +
            buildStatusSuffix(response.getStatus())
        );
      }

      String body = response.getBody();
      if (String.isBlank(body)) {
        return buildErrorResponse('AWS S3 returned an empty response.');
      }

      return parseResponseBody(body, requestedAccountName);
    } catch (S3AccountConfigurationException ex) {
      return buildErrorResponse(ex.getMessage());
    } catch (System.CalloutException ex) {
      return buildErrorResponse('AWS S3 callout failed: ' + ex.getMessage());
    } catch (Exception ex) {
      return buildErrorResponse(
        'Unable to retrieve account data from AWS S3: ' + ex.getMessage()
      );
    }
  }

  private static HttpResponse sendAccountRequest(S3AccountRequest config) {
    HttpResponse response = sendGet(buildEndpoint(config));

    if (shouldTryLegacyObjectPath(config, response.getStatusCode())) {
      response = sendGet(buildEndpoint(config, LEGACY_OBJECT_PATH));
    }

    return response;
  }

  private static HttpResponse sendGet(String endpoint) {
    HttpRequest request = new HttpRequest();
    request.setEndpoint(endpoint);
    request.setMethod('GET');
    request.setTimeout(TIMEOUT_MS);
    request.setHeader('Accept', 'application/json');

    return new Http().send(request);
  }

  private static Boolean shouldTryLegacyObjectPath(
    S3AccountRequest config,
    Integer statusCode
  ) {
    if (statusCode != 403 && statusCode != 404) {
      return false;
    }

    String rawPath = config == null ? null : config.s3ObjectPath;
    return String.isBlank(rawPath) ||
      normalizeObjectPath(rawPath) == DEFAULT_OBJECT_PATH;
  }

  private static S3AccountResponse parseResponseBody(
    String body,
    String requestedAccountName
  ) {
    S3AccountPayload payload;

    try {
      payload = deserializePayload(body);
    } catch (System.JSONException ex) {
      return buildErrorResponse(
        'AWS S3 returned malformed JSON: ' + ex.getMessage()
      );
    }

    List<S3AccountDTO> accounts = normalizeAccounts(payload);
    if (accounts.isEmpty()) {
      return buildErrorResponse(
        'AWS S3 response did not include any account records.'
      );
    }

    return buildFilteredResponse(accounts, requestedAccountName);
  }

  private static S3AccountPayload deserializePayload(String body) {
    S3AccountPayload payload = new S3AccountPayload();
    String normalizedBody = normalizeJsonBody(body);

    if (normalizedBody.startsWith('[')) {
      List<S3AccountEnvelope> envelopes = (List<S3AccountEnvelope>) JSON.deserialize(
        normalizedBody,
        List<S3AccountEnvelope>.class
      );

      if (containsAccountEnvelope(envelopes)) {
        payload.accounts = new List<S3AccountDTO>();

        for (S3AccountEnvelope envelope : envelopes) {
          if (envelope != null && envelope.account != null) {
            envelope.account.contacts = normalizeContacts(envelope.contacts);
            payload.accounts.add(envelope.account);
          }
        }

        return payload;
      }

      payload.accounts = (List<S3AccountDTO>) JSON.deserialize(
        normalizedBody,
        List<S3AccountDTO>.class
      );
      return payload;
    }

    return (S3AccountPayload) JSON.deserialize(
      normalizedBody,
      S3AccountPayload.class
    );
  }

  private static String normalizeJsonBody(String body) {
    String normalizedBody = body.trim();

    if (!normalizedBody.startsWith('```')) {
      return normalizedBody;
    }

    Integer firstLineBreak = normalizedBody.indexOf('\n');
    Integer lastFence = normalizedBody.lastIndexOf('```');

    if (firstLineBreak > -1 && lastFence > firstLineBreak) {
      return normalizedBody.substring(firstLineBreak + 1, lastFence).trim();
    }

    return normalizedBody;
  }

  private static Boolean containsAccountEnvelope(
    List<S3AccountEnvelope> envelopes
  ) {
    if (envelopes == null) {
      return false;
    }

    for (S3AccountEnvelope envelope : envelopes) {
      if (envelope != null && envelope.account != null) {
        return true;
      }
    }

    return false;
  }

  private static List<S3AccountDTO> normalizeAccounts(
    S3AccountPayload payload
  ) {
    List<S3AccountDTO> accounts = new List<S3AccountDTO>();

    if (payload == null) {
      return accounts;
    }

    if (payload.accounts != null) {
      for (S3AccountDTO account : payload.accounts) {
        if (account != null) {
          accounts.add(account);
        }
      }
    } else if (payload.account != null) {
      accounts.add(payload.account);
    }

    assignContacts(accounts, payload.contacts);
    return accounts;
  }

  private static void assignContacts(
    List<S3AccountDTO> accounts,
    List<S3ContactDTO> topLevelContacts
  ) {
    Map<String, S3AccountDTO> accountsById = new Map<String, S3AccountDTO>();

    for (S3AccountDTO account : accounts) {
      account.contacts = normalizeContacts(account.contacts);

      if (!String.isBlank(account.id)) {
        accountsById.put(account.id, account);
      }
    }

    List<S3ContactDTO> contacts = normalizeContacts(topLevelContacts);
    if (contacts.isEmpty()) {
      return;
    }

    for (S3ContactDTO contact : contacts) {
      S3AccountDTO matchedAccount;

      if (!String.isBlank(contact.accountId)) {
        matchedAccount = accountsById.get(contact.accountId);
      } else if (accounts.size() == 1) {
        matchedAccount = accounts[0];
      }

      if (matchedAccount != null) {
        matchedAccount.contacts.add(contact);
      }
    }
  }

  private static List<S3ContactDTO> normalizeContacts(
    List<S3ContactDTO> contacts
  ) {
    List<S3ContactDTO> normalizedContacts = new List<S3ContactDTO>();

    if (contacts == null) {
      return normalizedContacts;
    }

    for (S3ContactDTO contact : contacts) {
      if (contact != null) {
        normalizedContacts.add(contact);
      }
    }

    return normalizedContacts;
  }

  private static S3AccountResponse buildFilteredResponse(
    List<S3AccountDTO> accounts,
    String requestedAccountName
  ) {
    List<S3AccountDTO> matchedAccounts = new List<S3AccountDTO>();
    String normalizedRequest = normalizeSearchTerm(requestedAccountName)
      .toLowerCase();

    for (S3AccountDTO account : accounts) {
      if (
        account != null &&
        !String.isBlank(account.name) &&
        account.name.toLowerCase().contains(normalizedRequest)
      ) {
        account.contacts = normalizeContacts(account.contacts);
        matchedAccounts.add(account);
      }
    }

    S3AccountResponse response = new S3AccountResponse();
    response.success = true;
    response.accounts = matchedAccounts;
    response.account = matchedAccounts.isEmpty() ? null : matchedAccounts[0];
    response.contacts = flattenContacts(matchedAccounts);

    if (matchedAccounts.isEmpty()) {
      response.message =
        'No accounts matched "' +
        requestedAccountName +
        '". Check the Account Name and submit the form again.';
    } else if (matchedAccounts.size() == 1) {
      response.message =
        'Found 1 account matching "' +
        requestedAccountName +
        '".';
    } else {
      response.message =
        'Found ' +
        matchedAccounts.size() +
        ' accounts matching "' +
        requestedAccountName +
        '".';
    }

    return response;
  }

  private static List<S3ContactDTO> flattenContacts(
    List<S3AccountDTO> accounts
  ) {
    List<S3ContactDTO> contacts = new List<S3ContactDTO>();

    for (S3AccountDTO account : accounts) {
      contacts.addAll(normalizeContacts(account.contacts));
    }

    return contacts;
  }

  private static S3AccountResponse buildErrorResponse(String message) {
    S3AccountResponse response = new S3AccountResponse();
    response.success = false;
    response.message = message;
    response.account = null;
    response.accounts = new List<S3AccountDTO>();
    response.contacts = new List<S3ContactDTO>();
    return response;
  }

  private static S3AccountResponse buildInitialResponse() {
    S3AccountResponse response = new S3AccountResponse();
    response.success = true;
    response.message = null;
    response.account = null;
    response.accounts = new List<S3AccountDTO>();
    response.contacts = new List<S3ContactDTO>();
    return response;
  }

  private static List<S3AccountDTO> buildMockAccounts() {
    S3AccountDTO acmeKorea = new S3AccountDTO();
    acmeKorea.id = '001DEMO000001';
    acmeKorea.name = 'Acme Korea';
    acmeKorea.industry = 'Technology';
    acmeKorea.phone = '+82-2-1234-5678';
    acmeKorea.website = 'https://www.acme.example';
    acmeKorea.contacts = new List<S3ContactDTO>();

    S3ContactDTO firstContact = new S3ContactDTO();
    firstContact.id = '003DEMO000001';
    firstContact.accountId = acmeKorea.id;
    firstContact.firstName = 'Jin';
    firstContact.lastName = 'Kim';
    firstContact.email = 'jin.kim@acme.example';
    firstContact.title = 'VP Sales';
    acmeKorea.contacts.add(firstContact);

    S3ContactDTO secondContact = new S3ContactDTO();
    secondContact.id = '003DEMO000002';
    secondContact.accountId = acmeKorea.id;
    secondContact.firstName = 'Mina';
    secondContact.lastName = 'Park';
    secondContact.email = 'mina.park@acme.example';
    secondContact.title = 'Solution Architect';
    acmeKorea.contacts.add(secondContact);

    S3AccountDTO acmeJapan = new S3AccountDTO();
    acmeJapan.id = '001DEMO000002';
    acmeJapan.name = 'Acme Japan';
    acmeJapan.industry = 'Manufacturing';
    acmeJapan.phone = '+81-3-1234-5678';
    acmeJapan.website = 'https://www.acme-japan.example';
    acmeJapan.contacts = new List<S3ContactDTO>();

    S3ContactDTO thirdContact = new S3ContactDTO();
    thirdContact.id = '003DEMO000003';
    thirdContact.accountId = acmeJapan.id;
    thirdContact.firstName = 'Hana';
    thirdContact.lastName = 'Sato';
    thirdContact.email = 'hana.sato@acme-japan.example';
    thirdContact.title = 'Account Director';
    acmeJapan.contacts.add(thirdContact);

    return new List<S3AccountDTO>{ acmeKorea, acmeJapan };
  }

  private static String buildEndpoint(S3AccountRequest config) {
    String objectPath = normalizeObjectPath(
      config == null ? null : config.s3ObjectPath
    );
    String bucketOverride = normalizeBucketOverride(
      config == null ? null : config.bucketOverride
    );

    if (bucketOverride == null) {
      return NAMED_CREDENTIAL + objectPath;
    }

    return NAMED_CREDENTIAL + '/' + bucketOverride + objectPath;
  }

  private static String buildEndpoint(
    S3AccountRequest config,
    String objectPath
  ) {
    String bucketOverride = normalizeBucketOverride(
      config == null ? null : config.bucketOverride
    );

    if (bucketOverride == null) {
      return NAMED_CREDENTIAL + objectPath;
    }

    return NAMED_CREDENTIAL + '/' + bucketOverride + objectPath;
  }

  private static String normalizeObjectPath(String rawPath) {
    if (String.isBlank(rawPath)) {
      return DEFAULT_OBJECT_PATH;
    }

    String normalizedPath = rawPath.trim();
    if (normalizedPath.contains('://') || normalizedPath.contains('..')) {
      throw new S3AccountConfigurationException(
        'S3 object path must be a relative object key.'
      );
    }

    while (normalizedPath.startsWith('/')) {
      normalizedPath = normalizedPath.substring(1);
    }

    if (String.isBlank(normalizedPath)) {
      throw new S3AccountConfigurationException(
        'S3 object path cannot be empty.'
      );
    }

    return '/' + encodePath(normalizedPath);
  }

  private static String normalizeBucketOverride(String rawBucketOverride) {
    if (String.isBlank(rawBucketOverride)) {
      return null;
    }

    String bucketOverride = rawBucketOverride.trim();
    String invalidCharacters = bucketOverride.replaceAll('[A-Za-z0-9.-]', '');

    if (
      bucketOverride.length() < 3 ||
      bucketOverride.length() > 63 ||
      invalidCharacters.length() > 0
    ) {
      throw new S3AccountConfigurationException(
        'Bucket override must be a valid S3 bucket name.'
      );
    }

    return encodePathSegment(bucketOverride);
  }

  private static String encodePath(String path) {
    List<String> encodedSegments = new List<String>();

    for (String segment : path.split('/')) {
      if (!String.isBlank(segment)) {
        encodedSegments.add(encodePathSegment(segment));
      }
    }

    return String.join(encodedSegments, '/');
  }

  private static String encodePathSegment(String segment) {
    return EncodingUtil.urlEncode(segment, 'UTF-8').replace('+', '%20');
  }

  private static String normalizeSearchTerm(String value) {
    return String.isBlank(value) ? null : value.trim();
  }

  private static String buildStatusSuffix(String status) {
    return String.isBlank(status) ? '.' : ' (' + status + ').';
  }

  private class S3AccountPayload {
    public S3AccountDTO account;
    public List<S3AccountDTO> accounts;
    public List<S3ContactDTO> contacts;
  }

  private class S3AccountEnvelope {
    public S3AccountDTO account;
    public List<S3ContactDTO> contacts;
  }

  private class S3AccountConfigurationException extends Exception {
  }

  @JsonAccess(serializable='always' deserializable='always')
  global class S3AccountActionRequest {
    @InvocableVariable(label='S3 Account Request')
    global S3AccountRequest request;
  }

  @JsonAccess(serializable='always' deserializable='always')
  global class S3AccountActionResponse {
    @InvocableVariable(label='Account Data')
    global S3AccountResponse accountData;
  }
}
