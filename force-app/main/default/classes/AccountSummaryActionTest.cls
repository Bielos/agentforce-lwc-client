@IsTest
private class AccountSummaryActionTest {
  @IsTest
  static void getAccountSummary_findsAccountById() {
    Account accountRecord = new Account(
      Name = 'Acme Corp',
      Industry = 'Manufacturing',
      AnnualRevenue = 1250000
    );
    insert accountRecord;

    AccountSummaryAction.AccountSummaryInput inputItem = new AccountSummaryAction.AccountSummaryInput();
    inputItem.accountId = accountRecord.Id;
    AccountSummaryAction.GetAccountSummaryRequest requestItem = new AccountSummaryAction.GetAccountSummaryRequest();
    requestItem.account_input = inputItem;

    Test.startTest();
    List<AccountSummaryAction.GetAccountSummaryResponse> responses =
      AccountSummaryAction.getAccountSummary(
        new List<AccountSummaryAction.GetAccountSummaryRequest>{ requestItem }
      );
    Test.stopTest();

    System.assertEquals(1, responses.size());
    System.assertEquals(true, responses[0].is_success);
    System.assertNotEquals(null, responses[0].account_summary);
    System.assertEquals('Acme Corp', responses[0].account_summary.accountName);
    System.assertEquals(
      'Manufacturing',
      responses[0].account_summary.accountSubtitle
    );
    System.assertEquals('$1250000', responses[0].account_summary.arrLabel);
    System.assertNotEquals(null, responses[0].account_summary.accountUrl);
  }

  @IsTest
  static void getAccountSummary_findsAccountByName() {
    Account accountRecord = new Account(
      Name = 'Widget Co',
      Industry = 'Technology'
    );
    insert accountRecord;

    AccountSummaryAction.AccountSummaryInput inputItem = new AccountSummaryAction.AccountSummaryInput();
    inputItem.accountName = 'widget co';
    AccountSummaryAction.GetAccountSummaryRequest requestItem = new AccountSummaryAction.GetAccountSummaryRequest();
    requestItem.account_input = inputItem;

    List<AccountSummaryAction.GetAccountSummaryResponse> responses =
      AccountSummaryAction.getAccountSummary(
        new List<AccountSummaryAction.GetAccountSummaryRequest>{ requestItem }
      );

    System.assertEquals(1, responses.size());
    System.assertEquals(true, responses[0].is_success);
    System.assertEquals('Widget Co', responses[0].account_summary.accountName);
    System.assertEquals('Technology', responses[0].account_summary.accountSubtitle);
  }

  @IsTest
  static void getAccountSummary_returnsErrorWhenNoLookupInput() {
    AccountSummaryAction.GetAccountSummaryRequest requestItem = new AccountSummaryAction.GetAccountSummaryRequest();

    List<AccountSummaryAction.GetAccountSummaryResponse> responses =
      AccountSummaryAction.getAccountSummary(
        new List<AccountSummaryAction.GetAccountSummaryRequest>{ requestItem }
      );

    System.assertEquals(1, responses.size());
    System.assertEquals(false, responses[0].is_success);
    System.assertNotEquals(null, responses[0].error_message);
  }

  @IsTest
  static void getAccountSummary_surfacesOverdueOpportunityStep() {
    Account accountRecord = new Account(Name = 'Overdue Inc');
    insert accountRecord;
    insert new Opportunity(
      Name = 'Late Deal',
      AccountId = accountRecord.Id,
      StageName = 'Prospecting',
      CloseDate = Date.today().addDays(-10),
      Amount = 5000
    );

    AccountSummaryAction.AccountSummaryResult summary = runForAccount(accountRecord.Id);

    System.assert(
      hasStepLabeled(summary, 'Relancer les opportunités en retard'),
      'Expected an overdue-opportunity next step.'
    );
    System.assert(
      !hasStepLabeled(summary, 'Explorer les opportunités'),
      'Overdue step should take priority over generic exploration.'
    );
  }

  @IsTest
  static void getAccountSummary_surfacesOpenOpportunityStep() {
    Account accountRecord = new Account(Name = 'Active Inc');
    insert accountRecord;
    insert new Opportunity(
      Name = 'Live Deal',
      AccountId = accountRecord.Id,
      StageName = 'Prospecting',
      CloseDate = Date.today().addDays(30),
      Amount = 5000
    );

    AccountSummaryAction.AccountSummaryResult summary = runForAccount(accountRecord.Id);

    System.assert(
      hasStepLabeled(summary, 'Explorer les opportunités'),
      'Expected an open-opportunity exploration step.'
    );
  }

  @IsTest
  static void getAccountSummary_surfacesNewOpportunityStepWhenNoPipeline() {
    Account accountRecord = new Account(Name = 'Empty Inc');
    insert accountRecord;

    AccountSummaryAction.AccountSummaryResult summary = runForAccount(accountRecord.Id);

    System.assert(
      hasStepLabeled(summary, 'Identifier de nouvelles opportunités'),
      'Expected a new-opportunity step when there is no open pipeline.'
    );
    System.assert(
      hasStepLabeled(summary, 'Cartographier les contacts clés'),
      'Expected a contact-mapping step when there are no contacts.'
    );
  }

  private static AccountSummaryAction.AccountSummaryResult runForAccount(Id accountId) {
    AccountSummaryAction.AccountSummaryInput inputItem = new AccountSummaryAction.AccountSummaryInput();
    inputItem.accountId = accountId;
    AccountSummaryAction.GetAccountSummaryRequest requestItem = new AccountSummaryAction.GetAccountSummaryRequest();
    requestItem.account_input = inputItem;

    List<AccountSummaryAction.GetAccountSummaryResponse> responses =
      AccountSummaryAction.getAccountSummary(
        new List<AccountSummaryAction.GetAccountSummaryRequest>{ requestItem }
      );
    System.assertEquals(
      true,
      responses[0].is_success,
      'Lookup failed: ' + responses[0].error_message
    );
    return responses[0].account_summary;
  }

  private static Boolean hasStepLabeled(
    AccountSummaryAction.AccountSummaryResult summary,
    String label
  ) {
    for (AccountSummaryAction.NextStep step : summary.nextSteps) {
      if (step.label == label) {
        return true;
      }
    }
    return false;
  }

  @IsTest
  static void getAccountSummary_returnsErrorWhenAccountMissing() {
    AccountSummaryAction.AccountSummaryInput inputItem = new AccountSummaryAction.AccountSummaryInput();
    inputItem.accountName = 'Does Not Exist';
    AccountSummaryAction.GetAccountSummaryRequest requestItem = new AccountSummaryAction.GetAccountSummaryRequest();
    requestItem.account_input = inputItem;

    List<AccountSummaryAction.GetAccountSummaryResponse> responses =
      AccountSummaryAction.getAccountSummary(
        new List<AccountSummaryAction.GetAccountSummaryRequest>{ requestItem }
      );

    System.assertEquals(1, responses.size());
    System.assertEquals(false, responses[0].is_success);
    System.assert(responses[0].error_message.contains('not found'));
  }
}
