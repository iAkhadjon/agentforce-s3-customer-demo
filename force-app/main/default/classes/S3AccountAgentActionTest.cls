@IsTest
private class S3AccountAgentActionTest {
  private static final String MULTI_ACCOUNT_BODY =
    '{"accounts":[' +
    '{"id":"001DEMO000001","name":"Acme Korea","industry":"Technology",' +
    '"phone":"+82-2-1234-5678","website":"https://www.acme.example"},' +
    '{"id":"001DEMO000002","name":"Acme Japan","industry":"Manufacturing",' +
    '"phone":"+81-3-1234-5678","website":"https://www.acme-japan.example"}' +
    '],"contacts":[' +
    '{"id":"003DEMO000001","accountId":"001DEMO000001","firstName":"Jin","lastName":"Kim",' +
    '"email":"jin.kim@acme.example","title":"VP Sales"},' +
    '{"id":"003DEMO000002","accountId":"001DEMO000001","firstName":"Mina","lastName":"Park",' +
    '"email":"mina.park@acme.example","title":"Solution Architect"},' +
    '{"id":"003DEMO000003","accountId":"001DEMO000002","firstName":"Hana","lastName":"Sato",' +
    '"email":"hana.sato@acme-japan.example","title":"Account Director"}]}';

  private static final String LEGACY_BODY =
    '{"account":{"id":"001DEMO000001","name":"Acme Korea","industry":"Technology",' +
    '"phone":"+82-2-1234-5678","website":"https://www.acme.example"},' +
    '"contacts":[{"id":"003DEMO000001","firstName":"Jin","lastName":"Kim",' +
    '"email":"jin.kim@acme.example","title":"VP Sales"}]}';

  @IsTest
  static void successfulS3ResponseReturnsMatchingAccountData() {
    Test.setMock(
      HttpCalloutMock.class,
      new S3AccountMock(
        200,
        'OK',
        MULTI_ACCOUNT_BODY,
        'callout:AWS_S3_Demo/accounts.json'
      )
    );

    Test.startTest();
    List<S3AccountAgentAction.S3AccountActionResponse> responses = S3AccountAgentAction.getAccountData(
      new List<S3AccountAgentAction.S3AccountActionRequest>{
        buildRequest('Acme Korea', null)
      }
    );
    Test.stopTest();

    S3AccountResponse accountData = responses[0].accountData;
    System.assertEquals(true, accountData.success);
    System.assertEquals(1, accountData.accounts.size());
    System.assertEquals('Acme Korea', accountData.accounts[0].name);
    System.assertEquals('Technology', accountData.accounts[0].industry);
    System.assertEquals(2, accountData.accounts[0].contacts.size());
    System.assertEquals('Jin', accountData.accounts[0].contacts[0].firstName);
    System.assertEquals(2, accountData.contacts.size());
    System.assertEquals('Acme Korea', accountData.account.name);
  }

  @IsTest
  static void auraLookupReturnsMatchingAccountData() {
    Test.setMock(
      HttpCalloutMock.class,
      new S3AccountMock(
        200,
        'OK',
        MULTI_ACCOUNT_BODY,
        'callout:AWS_S3_Demo/accounts.json'
      )
    );

    Test.startTest();
    S3AccountResponse accountData = S3AccountAgentAction.lookupAccounts(
      'Acme Japan'
    );
    Test.stopTest();

    System.assertEquals(true, accountData.success);
    System.assertEquals(1, accountData.accounts.size());
    System.assertEquals('Acme Japan', accountData.account.name);
    System.assertEquals(1, accountData.contacts.size());
  }

  @IsTest
  static void partialAccountNameCanReturnSeveralAccounts() {
    Test.setMock(
      HttpCalloutMock.class,
      new S3AccountMock(
        200,
        'OK',
        MULTI_ACCOUNT_BODY,
        'callout:AWS_S3_Demo/accounts.json'
      )
    );

    Test.startTest();
    List<S3AccountAgentAction.S3AccountActionResponse> responses = S3AccountAgentAction.getAccountData(
      new List<S3AccountAgentAction.S3AccountActionRequest>{
        buildRequest('Acme', null)
      }
    );
    Test.stopTest();

    System.assertEquals(true, responses[0].accountData.success);
    System.assertEquals(2, responses[0].accountData.accounts.size());
    System.assertEquals(3, responses[0].accountData.contacts.size());
    System.assert(
      responses[0].accountData.message.contains('Found 2 accounts'),
      responses[0].accountData.message
    );
  }

  @IsTest
  static void legacySingleAccountShapeStillParses() {
    Test.setMock(
      HttpCalloutMock.class,
      new S3AccountMock(
        200,
        'OK',
        LEGACY_BODY,
        'callout:AWS_S3_Demo/accounts.json'
      )
    );

    Test.startTest();
    List<S3AccountAgentAction.S3AccountActionResponse> responses = S3AccountAgentAction.getAccountData(
      new List<S3AccountAgentAction.S3AccountActionRequest>{
        buildRequest('Korea', null)
      }
    );
    Test.stopTest();

    System.assertEquals(true, responses[0].accountData.success);
    System.assertEquals(1, responses[0].accountData.accounts.size());
    System.assertEquals(
      1,
      responses[0].accountData.accounts[0].contacts.size()
    );
  }

  @IsTest
  static void defaultAccountsJsonCanFallbackToLegacyAccountJson() {
    S3AccountRequest requestConfig = new S3AccountRequest();
    requestConfig.accountName = 'Korea';
    requestConfig.s3ObjectPath = '/accounts.json';

    S3AccountAgentAction.S3AccountActionRequest request = new S3AccountAgentAction.S3AccountActionRequest();
    request.request = requestConfig;

    Test.setMock(
      HttpCalloutMock.class,
      new S3AccountSequenceMock(
        new List<S3AccountMockResponse>{
          new S3AccountMockResponse(
            404,
            'Not Found',
            '{}',
            'callout:AWS_S3_Demo/accounts.json'
          ),
          new S3AccountMockResponse(
            200,
            'OK',
            LEGACY_BODY,
            'callout:AWS_S3_Demo/account.json'
          )
        }
      )
    );

    Test.startTest();
    List<S3AccountAgentAction.S3AccountActionResponse> responses = S3AccountAgentAction.getAccountData(
      new List<S3AccountAgentAction.S3AccountActionRequest>{ request }
    );
    Test.stopTest();

    System.assertEquals(true, responses[0].accountData.success);
    System.assertEquals('Acme Korea', responses[0].accountData.account.name);
    System.assertEquals(1, responses[0].accountData.contacts.size());
  }

  @IsTest
  static void rootArrayShapeStillParses() {
    Test.setMock(
      HttpCalloutMock.class,
      new S3AccountMock(
        200,
        'OK',
        '[{"id":"001DEMO000001","name":"Acme Korea","contacts":[{"id":"003DEMO000001","firstName":"Jin"}]}]',
        'callout:AWS_S3_Demo/accounts.json'
      )
    );

    Test.startTest();
    List<S3AccountAgentAction.S3AccountActionResponse> responses = S3AccountAgentAction.getAccountData(
      new List<S3AccountAgentAction.S3AccountActionRequest>{
        buildRequest('Acme Korea', null)
      }
    );
    Test.stopTest();

    System.assertEquals(true, responses[0].accountData.success);
    System.assertEquals(1, responses[0].accountData.accounts.size());
    System.assertEquals(1, responses[0].accountData.contacts.size());
  }

  @IsTest
  static void accountEnvelopeArrayShapeStillParses() {
    Test.setMock(
      HttpCalloutMock.class,
      new S3AccountMock(
        200,
        'OK',
        '```json\n[{"account":{"id":"001DEMO000001","name":"Acme Korea","industry":"Technology"},"contacts":[{"id":"003DEMO000001","firstName":"Jin"}]}]\n```',
        'callout:AWS_S3_Demo/accounts.json'
      )
    );

    Test.startTest();
    List<S3AccountAgentAction.S3AccountActionResponse> responses = S3AccountAgentAction.getAccountData(
      new List<S3AccountAgentAction.S3AccountActionRequest>{
        buildRequest('Acme Korea', null)
      }
    );
    Test.stopTest();

    System.assertEquals(true, responses[0].accountData.success);
    System.assertEquals(1, responses[0].accountData.accounts.size());
    System.assertEquals(
      'Technology',
      responses[0].accountData.account.industry
    );
    System.assertEquals(1, responses[0].accountData.contacts.size());
  }

  @IsTest
  static void noMatchingAccountsReturnsEmptySuccessState() {
    Test.setMock(
      HttpCalloutMock.class,
      new S3AccountMock(
        200,
        'OK',
        MULTI_ACCOUNT_BODY,
        'callout:AWS_S3_Demo/accounts.json'
      )
    );

    Test.startTest();
    List<S3AccountAgentAction.S3AccountActionResponse> responses = S3AccountAgentAction.getAccountData(
      new List<S3AccountAgentAction.S3AccountActionRequest>{
        buildRequest('Globex', null)
      }
    );
    Test.stopTest();

    System.assertEquals(true, responses[0].accountData.success);
    System.assertEquals(0, responses[0].accountData.accounts.size());
    System.assert(
      responses[0].accountData.message.contains('No accounts matched'),
      responses[0].accountData.message
    );
  }

  @IsTest
  static void customObjectPathAndBucketOverrideAreApplied() {
    Test.setMock(
      HttpCalloutMock.class,
      new S3AccountMock(
        200,
        'OK',
        MULTI_ACCOUNT_BODY,
        'callout:AWS_S3_Demo/demo-bucket/folder/account%20data.json'
      )
    );

    S3AccountRequest requestConfig = new S3AccountRequest();
    requestConfig.accountName = 'Acme';
    requestConfig.s3ObjectPath = '/folder/account data.json';
    requestConfig.bucketOverride = 'demo-bucket';

    S3AccountAgentAction.S3AccountActionRequest request = new S3AccountAgentAction.S3AccountActionRequest();
    request.request = requestConfig;

    Test.startTest();
    List<S3AccountAgentAction.S3AccountActionResponse> responses = S3AccountAgentAction.getAccountData(
      new List<S3AccountAgentAction.S3AccountActionRequest>{ request }
    );
    Test.stopTest();

    System.assertEquals(true, responses[0].accountData.success);
  }

  @IsTest
  static void failedResponseReturnsErrorState() {
    Test.setMock(
      HttpCalloutMock.class,
      new S3AccountMock(
        500,
        'Internal Server Error',
        '{"error":"server"}',
        'callout:AWS_S3_Demo/accounts.json'
      )
    );

    Test.startTest();
    List<S3AccountAgentAction.S3AccountActionResponse> responses = S3AccountAgentAction.getAccountData(
      new List<S3AccountAgentAction.S3AccountActionRequest>{
        buildRequest('Acme', null)
      }
    );
    Test.stopTest();

    System.assertEquals(false, responses[0].accountData.success);
    System.assert(
      responses[0].accountData.message.contains('HTTP 500'),
      responses[0].accountData.message
    );
    System.assertEquals(0, responses[0].accountData.accounts.size());
  }

  @IsTest
  static void handlesForbiddenStatus() {
    Test.setMock(
      HttpCalloutMock.class,
      new S3AccountSequenceMock(
        new List<S3AccountMockResponse>{
          new S3AccountMockResponse(
            403,
            'Forbidden',
            '{}',
            'callout:AWS_S3_Demo/accounts.json'
          ),
          new S3AccountMockResponse(
            403,
            'Forbidden',
            '{}',
            'callout:AWS_S3_Demo/account.json'
          )
        }
      )
    );

    Test.startTest();
    List<S3AccountAgentAction.S3AccountActionResponse> forbiddenResponses = S3AccountAgentAction.getAccountData(
      new List<S3AccountAgentAction.S3AccountActionRequest>{
        buildRequest('Acme', null)
      }
    );
    Test.stopTest();

    System.assertEquals(false, forbiddenResponses[0].accountData.success);
    System.assert(
      forbiddenResponses[0].accountData.message.contains('HTTP 403'),
      forbiddenResponses[0].accountData.message
    );
  }

  @IsTest
  static void handlesNotFoundStatus() {
    Test.setMock(
      HttpCalloutMock.class,
      new S3AccountSequenceMock(
        new List<S3AccountMockResponse>{
          new S3AccountMockResponse(
            404,
            'Not Found',
            '{}',
            'callout:AWS_S3_Demo/accounts.json'
          ),
          new S3AccountMockResponse(
            404,
            'Not Found',
            '{}',
            'callout:AWS_S3_Demo/account.json'
          )
        }
      )
    );

    Test.startTest();
    List<S3AccountAgentAction.S3AccountActionResponse> notFoundResponses = S3AccountAgentAction.getAccountData(
      new List<S3AccountAgentAction.S3AccountActionRequest>{
        buildRequest('Acme', null)
      }
    );
    Test.stopTest();

    System.assertEquals(false, notFoundResponses[0].accountData.success);
    System.assert(
      notFoundResponses[0].accountData.message.contains('HTTP 404'),
      notFoundResponses[0].accountData.message
    );
  }

  @IsTest
  static void malformedJsonReturnsErrorState() {
    Test.setMock(
      HttpCalloutMock.class,
      new S3AccountMock(
        200,
        'OK',
        '{"accounts":',
        'callout:AWS_S3_Demo/accounts.json'
      )
    );

    Test.startTest();
    List<S3AccountAgentAction.S3AccountActionResponse> responses = S3AccountAgentAction.getAccountData(
      new List<S3AccountAgentAction.S3AccountActionRequest>{
        buildRequest('Acme', null)
      }
    );
    Test.stopTest();

    System.assertEquals(false, responses[0].accountData.success);
    System.assert(
      responses[0].accountData.message.contains('malformed JSON'),
      responses[0].accountData.message
    );
  }

  @IsTest
  static void emptyResponseReturnsErrorState() {
    Test.setMock(
      HttpCalloutMock.class,
      new S3AccountMock(200, 'OK', '   ', 'callout:AWS_S3_Demo/accounts.json')
    );

    Test.startTest();
    List<S3AccountAgentAction.S3AccountActionResponse> responses = S3AccountAgentAction.getAccountData(
      new List<S3AccountAgentAction.S3AccountActionRequest>{
        buildRequest('Acme', null)
      }
    );
    Test.stopTest();

    System.assertEquals(false, responses[0].accountData.success);
    System.assert(
      responses[0].accountData.message.contains('empty response'),
      responses[0].accountData.message
    );
  }

  @IsTest
  static void missingAccountRecordsReturnsErrorState() {
    Test.setMock(
      HttpCalloutMock.class,
      new S3AccountMock(
        200,
        'OK',
        '{"contacts":[]}',
        'callout:AWS_S3_Demo/accounts.json'
      )
    );

    Test.startTest();
    List<S3AccountAgentAction.S3AccountActionResponse> responses = S3AccountAgentAction.getAccountData(
      new List<S3AccountAgentAction.S3AccountActionRequest>{
        buildRequest('Acme', null)
      }
    );
    Test.stopTest();

    System.assertEquals(false, responses[0].accountData.success);
    System.assert(
      responses[0].accountData.message.contains('account records'),
      responses[0].accountData.message
    );
  }

  @IsTest
  static void missingAccountNameReturnsFormErrorBeforeCallout() {
    Test.startTest();
    List<S3AccountAgentAction.S3AccountActionResponse> responses = S3AccountAgentAction.getAccountData(
      new List<S3AccountAgentAction.S3AccountActionRequest>{
        buildRequest(null, null)
      }
    );
    Test.stopTest();

    System.assertEquals(false, responses[0].accountData.success);
    System.assert(
      responses[0].accountData.message.contains('Account Name'),
      responses[0].accountData.message
    );
  }

  @IsTest
  static void emptyActionLaunchReturnsInitialRendererPayloadWithoutCallout() {
    Test.startTest();
    List<S3AccountAgentAction.S3AccountActionResponse> responses = S3AccountAgentAction.getAccountData(
      null
    );
    Test.stopTest();

    System.assertEquals(true, responses[0].accountData.success);
    System.assertEquals(null, responses[0].accountData.message);
    System.assertEquals(0, responses[0].accountData.accounts.size());
    System.assertEquals(0, responses[0].accountData.contacts.size());
    System.assertEquals(null, responses[0].accountData.account);
  }

  @IsTest
  static void mockModeReturnsFilteredSampleDataWithoutCallout() {
    S3AccountRequest requestConfig = new S3AccountRequest();
    requestConfig.accountName = 'Acme';
    requestConfig.mockMode = true;

    S3AccountAgentAction.S3AccountActionRequest request = new S3AccountAgentAction.S3AccountActionRequest();
    request.request = requestConfig;

    Test.startTest();
    List<S3AccountAgentAction.S3AccountActionResponse> responses = S3AccountAgentAction.getAccountData(
      new List<S3AccountAgentAction.S3AccountActionRequest>{ request }
    );
    Test.stopTest();

    System.assertEquals(true, responses[0].accountData.success);
    System.assertEquals(2, responses[0].accountData.accounts.size());
    System.assertEquals(3, responses[0].accountData.contacts.size());
  }

  @IsTest
  static void invalidConfigReturnsErrorBeforeCallout() {
    S3AccountRequest requestConfig = new S3AccountRequest();
    requestConfig.accountName = 'Acme';
    requestConfig.s3ObjectPath = 'https://example.com/accounts.json';

    S3AccountAgentAction.S3AccountActionRequest request = new S3AccountAgentAction.S3AccountActionRequest();
    request.request = requestConfig;

    Test.startTest();
    List<S3AccountAgentAction.S3AccountActionResponse> responses = S3AccountAgentAction.getAccountData(
      new List<S3AccountAgentAction.S3AccountActionRequest>{ request }
    );
    Test.stopTest();

    System.assertEquals(false, responses[0].accountData.success);
    System.assert(
      responses[0].accountData.message.contains('relative object key'),
      responses[0].accountData.message
    );
  }

  private static S3AccountAgentAction.S3AccountActionRequest buildRequest(
    String accountName,
    String objectPath
  ) {
    S3AccountRequest requestConfig = new S3AccountRequest();
    requestConfig.accountName = accountName;
    requestConfig.s3ObjectPath = objectPath;

    S3AccountAgentAction.S3AccountActionRequest request = new S3AccountAgentAction.S3AccountActionRequest();
    request.request = requestConfig;
    return request;
  }

  private class S3AccountMock implements HttpCalloutMock {
    private Integer statusCode;
    private String status;
    private String body;
    private String expectedEndpoint;

    S3AccountMock(
      Integer statusCode,
      String status,
      String body,
      String expectedEndpoint
    ) {
      this.statusCode = statusCode;
      this.status = status;
      this.body = body;
      this.expectedEndpoint = expectedEndpoint;
    }

    public HttpResponse respond(HttpRequest request) {
      System.assertEquals('GET', request.getMethod());
      System.assertEquals(expectedEndpoint, request.getEndpoint());
      System.assertEquals('application/json', request.getHeader('Accept'));

      HttpResponse response = new HttpResponse();
      response.setStatusCode(statusCode);
      response.setStatus(status);
      response.setBody(body);
      return response;
    }
  }

  private class S3AccountSequenceMock implements HttpCalloutMock {
    private List<S3AccountMockResponse> responses;
    private Integer responseIndex = 0;

    S3AccountSequenceMock(List<S3AccountMockResponse> responses) {
      this.responses = responses;
    }

    public HttpResponse respond(HttpRequest request) {
      System.assert(
        responseIndex < responses.size(),
        'Unexpected extra callout to ' + request.getEndpoint()
      );

      S3AccountMockResponse mockResponse = responses[responseIndex];
      responseIndex++;

      System.assertEquals('GET', request.getMethod());
      System.assertEquals(mockResponse.expectedEndpoint, request.getEndpoint());
      System.assertEquals('application/json', request.getHeader('Accept'));

      HttpResponse response = new HttpResponse();
      response.setStatusCode(mockResponse.statusCode);
      response.setStatus(mockResponse.status);
      response.setBody(mockResponse.body);
      return response;
    }
  }

  private class S3AccountMockResponse {
    Integer statusCode;
    String status;
    String body;
    String expectedEndpoint;

    S3AccountMockResponse(
      Integer statusCode,
      String status,
      String body,
      String expectedEndpoint
    ) {
      this.statusCode = statusCode;
      this.status = status;
      this.body = body;
      this.expectedEndpoint = expectedEndpoint;
    }
  }
}
