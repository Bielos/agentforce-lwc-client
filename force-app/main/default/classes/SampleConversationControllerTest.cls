@isTest
private class SampleConversationControllerTest {
  /**
   * Build a user that holds the SampleConversationAccess permission set so the
   * controller's user-mode queries/DML have field-level security granted.
   */
  private static User buildAccessUser() {
    String unique = 'scp' + String.valueOf(Datetime.now().getTime());
    // Reuse the running user's profile so the test is locale-independent; the
    // permission set below is what grants field-level security to the fields.
    User u = new User(
      Alias = 'scp',
      Email = 'scp.tester@example.com.invalid',
      EmailEncodingKey = 'UTF-8',
      LastName = 'Tester',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US',
      ProfileId = UserInfo.getProfileId(),
      TimeZoneSidKey = 'America/Los_Angeles',
      Username = unique + '@example.com.invalid'
    );
    insert u;

    PermissionSet ps = [
      SELECT Id
      FROM PermissionSet
      WHERE Name = 'SampleConversationAccess'
      LIMIT 1
    ];
    insert new PermissionSetAssignment(
      AssigneeId = u.Id,
      PermissionSetId = ps.Id
    );
    return u;
  }

  private static Sample_Conversation__c createConversation() {
    Sample_Conversation__c convo = new Sample_Conversation__c(
      Name = 'Complaint rehearsal',
      Transcript__c = 'User: My order is late.\n\nAgent: (pending)',
      Skill_API_Name__c = 'manage_customer_complaints',
      Agent_API_Name__c = 'SearchAgent'
    );
    insert convo;
    return convo;
  }

  @isTest
  static void getConversationReturnsRecord() {
    User accessUser = buildAccessUser();

    System.runAs(accessUser) {
      Sample_Conversation__c convo = createConversation();

      Test.startTest();
      Sample_Conversation__c result = SampleConversationController.getConversation(
        convo.Id
      );
      Test.stopTest();

      System.assertEquals(
        convo.Id,
        result.Id,
        'Should return the requested record'
      );
      System.assertEquals(
        'SearchAgent',
        result.Agent_API_Name__c,
        'Agent API name should round-trip'
      );
    }
  }

  @isTest
  static void saveTranscriptPersistsChanges() {
    User accessUser = buildAccessUser();

    System.runAs(accessUser) {
      Sample_Conversation__c convo = createConversation();
      String updated = 'User: My order is late.\n\nAgent: I can help with that.';

      Test.startTest();
      Sample_Conversation__c result = SampleConversationController.saveTranscript(
        convo.Id,
        updated,
        'SupportAgent',
        12.34
      );
      Test.stopTest();

      System.assertEquals(
        updated,
        result.Transcript__c,
        'Transcript should be updated and reloaded'
      );
      System.assertEquals(
        'SupportAgent',
        result.Agent_API_Name__c,
        'Chosen agent should be persisted'
      );
      System.assertEquals(
        12.34,
        result.Last_Play_Duration__c,
        'Play duration should be persisted'
      );
    }
  }

  @isTest
  static void getConversationsReturnsRecords() {
    User accessUser = buildAccessUser();

    System.runAs(accessUser) {
      createConversation();

      Test.startTest();
      List<Sample_Conversation__c> results = SampleConversationController.getConversations();
      Test.stopTest();

      System.assertEquals(1, results.size(), 'Should list the conversation');
      System.assertEquals(
        'SearchAgent',
        results[0].Agent_API_Name__c,
        'Player fields should be selected'
      );
    }
  }

  @isTest
  static void getSkillContentHandlesBlankAndMissing() {
    Test.startTest();
    String blank = SampleConversationController.getSkillContent('');
    String missing = SampleConversationController.getSkillContent(
      'no_such_skill_xyz'
    );
    Test.stopTest();

    System.assertEquals(null, blank, 'Blank name returns null');
    System.assertEquals(null, missing, 'Unknown skill returns null');
  }

  @isTest
  static void importConversationsCreatesRecords() {
    User accessUser = buildAccessUser();

    System.runAs(accessUser) {
      List<Sample_Conversation__c> rows = new List<Sample_Conversation__c>{
        new Sample_Conversation__c(
          Name = 'Plan Monday',
          Skill_API_Name__c = 'plan_my_day',
          Agent_API_Name__c = 'SearchAgent',
          Description__c = 'A busy Monday',
          Transcript__c = 'User: Hi\n\nAgent: Hello'
        ),
        new Sample_Conversation__c(Name = '  '),
        new Sample_Conversation__c(
          Name = 'Refund',
          Agent_API_Name__c = 'SearchAgent'
        )
      };

      Test.startTest();
      SampleConversationController.ImportResult result = SampleConversationController.importConversations(
        rows
      );
      Test.stopTest();

      System.assertEquals(2, result.created, 'Named rows should be inserted');
      System.assertEquals(0, result.failures.size(), 'No row should fail');
      System.assertEquals(
        2,
        [
          SELECT COUNT()
          FROM Sample_Conversation__c
        ],
        'Two conversations should exist'
      );
    }
  }

  @isTest
  static void importConversationsRejectsEmptyPayload() {
    User accessUser = buildAccessUser();

    System.runAs(accessUser) {
      Boolean threw = false;
      try {
        Test.startTest();
        SampleConversationController.importConversations(
          new List<Sample_Conversation__c>()
        );
        Test.stopTest();
      } catch (AuraHandledException ex) {
        threw = true;
        System.assertEquals(
          'No sample conversations found in that file.',
          ex.getMessage(),
          'Empty payload should be rejected'
        );
      }
      System.assertEquals(true, threw, 'Empty list should throw');
    }
  }
}
