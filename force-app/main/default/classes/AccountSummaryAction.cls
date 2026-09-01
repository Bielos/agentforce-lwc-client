/**
 * Invocable action that returns account summary data for Agentforce output rendering.
 */
global with sharing class AccountSummaryAction {
  /**
   * Input for account summary lookup.
   */
  global class AccountSummaryInput {
    @InvocableVariable(
      label='Account Id'
      description='Optional Account record id.'
      required=false
    )
    public Id accountId;

    @InvocableVariable(
      label='Account Name'
      description='Optional account name when id is not provided.'
      required=false
    )
    public String accountName;
  }

  /**
   * Structured output matching the accountSummaryType CLT and widget schema.
   */
  global class AccountSummaryResult {
    @InvocableVariable(
      label='Account Name'
      description='Primary account display name.'
      required=false
    )
    public String accountName;

    @InvocableVariable(
      label='Account Subtitle'
      description='Secondary account line.'
      required=false
    )
    public String accountSubtitle;

    @InvocableVariable(
      label='Owner Name'
      description='Account owner full name.'
      required=false
    )
    public String ownerName;

    @InvocableVariable(
      label='ARR Label'
      description='Formatted annual recurring revenue label.'
      required=false
    )
    public String arrLabel;

    @InvocableVariable(
      label='Account URL'
      description='Absolute URL to open the account.'
      required=false
    )
    public String accountUrl;

    @InvocableVariable(label='Account Tier' description='Commercial tier label for the account.')
    public String accountTier;

    @InvocableVariable(label='ARR Delta Label' description='ARR trend label.')
    public String arrDeltaLabel;

    @InvocableVariable(label='Employees Label' description='Employee count display value.')
    public String employeesLabel;

    @InvocableVariable(label='Health Score' description='Health score from 0 to 100.')
    public Decimal healthScore;

    @InvocableVariable(label='Renewal Date Label' description='Renewal date display text.')
    public String renewalDateLabel;

    @InvocableVariable(label='Renewal Status Label' description='Renewal status display label.')
    public String renewalStatusLabel;

    @InvocableVariable(label='Renewal Status Variant' description='UI variant for renewal status badge.')
    public String renewalStatusVariant;

    @InvocableVariable(label='Owner Initials' description='Initials used by owner avatar.')
    public String ownerInitials;

    @InvocableVariable(label='Open Pipeline Label' description='Formatted open pipeline amount label.')
    public String openPipelineLabel;

    @InvocableVariable(label='Opportunities' description='Top related opportunities for display.')
    public List<OpportunitySummary> opportunities;

    @InvocableVariable(label='Contacts' description='Recent related contacts for display.')
    public List<ContactSummary> contacts;

    @InvocableVariable(label='Policies' description='Insurance policies for display.')
    public List<PolicySummary> policies;

    @InvocableVariable(label='Next Steps' description='Suggested next-step actions rendered as buttons.')
    public List<NextStep> nextSteps;

  }

  global class NextStep {
    @InvocableVariable(label='Label' description='Button label shown to the user.')
    public String label;
    @InvocableVariable(label='Prompt' description='Message sent to the agent when the button is clicked.')
    public String prompt;
  }

  global class OpportunitySummary {
    @InvocableVariable(label='Name' description='Opportunity name')
    public String name;
    @InvocableVariable(label='Close Date Label' description='Formatted close date')
    public String closeDateLabel;
    @InvocableVariable(label='Stage Name' description='Opportunity stage')
    public String stageName;
    @InvocableVariable(label='Stage Variant' description='Badge variant by stage')
    public String stageVariant;
    @InvocableVariable(label='Amount Label' description='Formatted amount')
    public String amountLabel;
  }

  global class ContactSummary {
    @InvocableVariable(label='Initials' description='Contact initials')
    public String initials;
    @InvocableVariable(label='Name' description='Contact full name')
    public String name;
    @InvocableVariable(label='Title' description='Contact title')
    public String title;
    @InvocableVariable(label='Last Touch Label' description='Last touch display text')
    public String lastTouchLabel;
  }

  global class PolicySummary {
    @InvocableVariable(label='Policy Name' description='Policy display name')
    public String name;
    @InvocableVariable(label='Policy Status' description='Policy status label')
    public String statusLabel;
    @InvocableVariable(label='Premium Label' description='Policy premium amount label')
    public String amountLabel;
    @InvocableVariable(label='Renewal Date Label' description='Policy renewal date display text')
    public String renewalDateLabel;
  }

  /**
   * Invocable request wrapper for Agentforce assets.
   */
  global class GetAccountSummaryRequest {
    @InvocableVariable(
      label='Account Input'
      description='Input payload containing accountId or accountName.'
      required=true
    )
    public AccountSummaryInput account_input;
  }

  /**
   * Invocable response wrapper for Agentforce assets.
   */
  global class GetAccountSummaryResponse {
    @InvocableVariable(
      label='Account Summary'
      description='Structured account summary payload for output rendering.'
    )
    public AccountSummaryResult account_summary;

    @InvocableVariable(
      label='Is Success'
      description='Indicates whether the account summary was resolved successfully.'
    )
    public Boolean is_success;

    @InvocableVariable(
      label='Error Message'
      description='Error details when is_success is false.'
    )
    public String error_message;
  }

  /**
   * Returns account summary output for Agentforce actions.
   *
   * @param requests List of account lookup requests.
   * @return List of responses aligned to input order.
   */
  @InvocableMethod(
    label='Get Account Summary'
    description='Returns account summary fields for widget rendering.'
    category='Agentforce'
  )
  global static List<GetAccountSummaryResponse> getAccountSummary(
    List<GetAccountSummaryRequest> requests
  ) {
    List<GetAccountSummaryRequest> safeRequests = requests == null
      ? new List<GetAccountSummaryRequest>()
      : requests;
    if (safeRequests.isEmpty()) {
      return new List<GetAccountSummaryResponse>();
    }

    Set<Id> requestedAccountIds = new Set<Id>();
    Set<String> requestedAccountNames = new Set<String>();
    for (GetAccountSummaryRequest requestItem : safeRequests) {
      if (requestItem == null || requestItem.account_input == null) {
        continue;
      }
      if (requestItem.account_input.accountId != null) {
        requestedAccountIds.add(requestItem.account_input.accountId);
      } else if (!String.isBlank(requestItem.account_input.accountName)) {
        requestedAccountNames.add(
          requestItem.account_input.accountName.trim().toLowerCase()
        );
      }
    }

    List<Account> candidateAccounts = new List<Account>();
    if (!requestedAccountIds.isEmpty() || !requestedAccountNames.isEmpty()) {
      candidateAccounts = [
        SELECT
          Id,
          Name,
          Industry,
          Type,
          AnnualRevenue,
          NumberOfEmployees,
          Owner.Name,
          (SELECT Name, CloseDate, StageName, Amount FROM Opportunities ORDER BY CloseDate ASC LIMIT 3),
          (SELECT Name, Title, LastModifiedDate FROM Contacts ORDER BY LastModifiedDate DESC LIMIT 5)
        FROM Account
        WHERE Id IN :requestedAccountIds OR Name IN :requestedAccountNames
        WITH USER_MODE
      ];
    }

    Map<Id, Account> accountsById = new Map<Id, Account>(candidateAccounts);
    Map<String, Account> accountsByNormalizedName = new Map<String, Account>();
    for (Account accountRecord : candidateAccounts) {
      String normalizedName = String.isBlank(accountRecord.Name)
        ? null
        : accountRecord.Name.trim().toLowerCase();
      if (normalizedName != null && !accountsByNormalizedName.containsKey(normalizedName)) {
        accountsByNormalizedName.put(normalizedName, accountRecord);
      }
    }

    List<GetAccountSummaryResponse> responses = new List<GetAccountSummaryResponse>();
    for (GetAccountSummaryRequest requestItem : safeRequests) {
      responses.add(
        buildResponse(
          requestItem,
          accountsById,
          accountsByNormalizedName
        )
      );
    }
    return responses;
  }

  private static GetAccountSummaryResponse buildResponse(
    GetAccountSummaryRequest requestItem,
    Map<Id, Account> accountsById,
    Map<String, Account> accountsByNormalizedName
  ) {
    GetAccountSummaryResponse response = new GetAccountSummaryResponse();
    try {
      if (requestItem == null || requestItem.account_input == null) {
        throw new AccountSummaryActionException('Request entry is null.');
      }

      Account selectedAccount;
      if (requestItem.account_input.accountId != null) {
        selectedAccount = accountsById.get(requestItem.account_input.accountId);
      } else if (!String.isBlank(requestItem.account_input.accountName)) {
        selectedAccount = accountsByNormalizedName.get(
          requestItem.account_input.accountName.trim().toLowerCase()
        );
      } else {
        throw new AccountSummaryActionException(
          'Either accountId or accountName must be provided.'
        );
      }

      if (selectedAccount == null) {
        throw new AccountSummaryActionException('Account not found.');
      }

      AccountSummaryResult result = new AccountSummaryResult();
      result.accountName = selectedAccount.Name;
      result.accountSubtitle = String.isBlank(selectedAccount.Industry)
        ? 'Account'
        : selectedAccount.Industry;
      result.ownerName = selectedAccount.Owner == null
        ? null
        : selectedAccount.Owner.Name;
      result.ownerInitials = buildInitials(result.ownerName);
      result.arrLabel = selectedAccount.AnnualRevenue == null
        ? 'N/A'
        : '$' + String.valueOf(selectedAccount.AnnualRevenue.setScale(0));
      result.accountTier = String.isBlank(selectedAccount.Type) ? 'Standard' : selectedAccount.Type;
      result.arrDeltaLabel = 'YoY +0%';
      result.employeesLabel = selectedAccount.NumberOfEmployees == null
        ? 'N/A'
        : String.valueOf(selectedAccount.NumberOfEmployees);
      result.healthScore = 80;
      result.renewalDateLabel = 'N/A';
      result.renewalStatusLabel = 'On Track';
      result.renewalStatusVariant = 'success';
      result.opportunities = new List<OpportunitySummary>();
      Decimal openPipelineAmount = 0;
      Integer openOpportunityCount = 0;
      List<String> overdueOpportunityNames = new List<String>();
      Date today = Date.today();
      for (Opportunity opportunityRecord : selectedAccount.Opportunities) {
        OpportunitySummary opportunitySummary = new OpportunitySummary();
        opportunitySummary.name = opportunityRecord.Name;
        opportunitySummary.closeDateLabel = opportunityRecord.CloseDate == null
          ? 'TBD'
          : opportunityRecord.CloseDate.format();
        opportunitySummary.stageName = opportunityRecord.StageName;
        opportunitySummary.stageVariant = mapStageVariant(opportunityRecord.StageName);
        opportunitySummary.amountLabel = opportunityRecord.Amount == null
          ? 'N/A'
          : '$' + String.valueOf(opportunityRecord.Amount.setScale(0));
        Boolean isOpen = String.isBlank(opportunityRecord.StageName)
          || !opportunityRecord.StageName.toLowerCase().contains('closed');
        if (isOpen) {
          openOpportunityCount++;
          if (opportunityRecord.Amount != null) {
            openPipelineAmount += opportunityRecord.Amount;
          }
          if (
            opportunityRecord.CloseDate != null &&
            opportunityRecord.CloseDate < today
          ) {
            overdueOpportunityNames.add(opportunityRecord.Name);
          }
        }
        result.opportunities.add(opportunitySummary);
      }
      result.policies = fetchPoliciesForAccount(selectedAccount.Id);
      if (result.policies.isEmpty()) {
        result.policies = derivePoliciesFromOpportunities(result.opportunities);
      }
      result.openPipelineLabel = String.valueOf(result.policies.size()) + ' active';
      result.contacts = new List<ContactSummary>();
      Datetime mostRecentTouch;
      for (Contact contactRecord : selectedAccount.Contacts) {
        ContactSummary contactSummary = new ContactSummary();
        contactSummary.initials = buildInitials(contactRecord.Name);
        contactSummary.name = contactRecord.Name;
        contactSummary.title = String.isBlank(contactRecord.Title) ? 'Contact' : contactRecord.Title;
        contactSummary.lastTouchLabel = contactRecord.LastModifiedDate == null
          ? 'recently'
          : contactRecord.LastModifiedDate.format('MMM d, yyyy');
        if (
          contactRecord.LastModifiedDate != null &&
          (mostRecentTouch == null || contactRecord.LastModifiedDate > mostRecentTouch)
        ) {
          mostRecentTouch = contactRecord.LastModifiedDate;
        }
        result.contacts.add(contactSummary);
      }
      result.accountUrl =
        URL.getOrgDomainUrl().toExternalForm() + '/' + selectedAccount.Id;

      NextStepSignals signals = new NextStepSignals();
      signals.accountName = result.accountName;
      signals.openOpportunityCount = openOpportunityCount;
      signals.overdueOpportunityNames = overdueOpportunityNames;
      signals.hasContacts = !result.contacts.isEmpty();
      signals.daysSinceLastTouch = mostRecentTouch == null
        ? null
        : mostRecentTouch.date().daysBetween(today);
      result.nextSteps = buildNextSteps(signals);

      response.account_summary = result;
      response.is_success = true;
      return response;
    } catch (Exception ex) {
      response.is_success = false;
      response.error_message = ex.getTypeName() + ': ' + ex.getMessage();
      return response;
    }
  }

  public class AccountSummaryActionException extends Exception {
  }

  /**
   * Aggregated account signals used to decide which next-step actions to surface.
   */
  private class NextStepSignals {
    public String accountName;
    public Integer openOpportunityCount = 0;
    public List<String> overdueOpportunityNames = new List<String>();
    public Boolean hasContacts = false;
    public Integer daysSinceLastTouch;
  }

  /** Contacts untouched for this many days trigger a re-engagement suggestion. */
  private static final Integer STALE_CONTACT_DAYS = 60;

  /**
   * Builds the suggested next-step actions rendered as buttons in the widget.
   * The list adapts to the account's live signals (overdue deals, empty
   * pipeline, stale relationships) so the buttons reflect the real situation.
   *
   * @param signals Aggregated account signals.
   * @return Ordered list of next-step actions.
   */
  private static List<NextStep> buildNextSteps(NextStepSignals signals) {
    String safeName = String.isBlank(signals.accountName)
      ? 'ce client'
      : signals.accountName;
    List<NextStep> steps = new List<NextStep>();

    // Always relevant: prepare for the next conversation.
    steps.add(
      newStep(
        'Préparer le prochain rendez-vous',
        'Aide-moi à préparer le prochain rendez-vous avec ' +
          safeName +
          ' : points clés à aborder, sujets ouverts et objectifs.'
      )
    );

    // Overdue open deals take priority over generic pipeline exploration.
    if (!signals.overdueOpportunityNames.isEmpty()) {
      steps.add(
        newStep(
          'Relancer les opportunités en retard',
          'Les opportunités suivantes de ' +
            safeName +
            ' ont dépassé leur date de clôture prévue : ' +
            String.join(signals.overdueOpportunityNames, ', ') +
            '. Propose un plan de relance et les prochaines actions concrètes.'
        )
      );
    } else if (signals.openOpportunityCount > 0) {
      steps.add(
        newStep(
          'Explorer les opportunités',
          'Analyse les opportunités ouvertes de ' +
            safeName +
            ' et propose les meilleures actions pour les faire avancer.'
        )
      );
    } else {
      steps.add(
        newStep(
          'Identifier de nouvelles opportunités',
          safeName +
            ' n\'a aucune opportunité ouverte. Identifie des pistes de développement et des offres pertinentes à proposer.'
        )
      );
    }

    // Relationship health: no contacts, or nobody touched recently.
    if (!signals.hasContacts) {
      steps.add(
        newStep(
          'Cartographier les contacts clés',
          'Aucun contact n\'est associé à ' +
            safeName +
            '. Aide-moi à identifier les interlocuteurs clés à rencontrer et à structurer une prise de contact.'
        )
      );
    } else if (
      signals.daysSinceLastTouch != null &&
      signals.daysSinceLastTouch >= STALE_CONTACT_DAYS
    ) {
      steps.add(
        newStep(
          'Reprendre contact',
          'Aucune interaction avec ' +
            safeName +
            ' depuis ' +
            String.valueOf(signals.daysSinceLastTouch) +
            ' jours. Propose un message de reprise de contact et un motif pertinent pour renouer le dialogue.'
        )
      );
    }

    return steps;
  }

  private static NextStep newStep(String label, String prompt) {
    NextStep step = new NextStep();
    step.label = label;
    step.prompt = prompt;
    return step;
  }

  private static String mapStageVariant(String stageName) {
    if (String.isBlank(stageName)) {
      return 'neutral';
    }
    String normalized = stageName.toLowerCase();
    if (normalized.contains('closed won') || normalized.contains('proposal')) {
      return 'success';
    }
    if (normalized.contains('closed lost')) {
      return 'destructive';
    }
    if (normalized.contains('qualification') || normalized.contains('prospecting')) {
      return 'warning';
    }
    return 'info';
  }

  private static String buildInitials(String fullName) {
    if (String.isBlank(fullName)) {
      return 'NA';
    }
    List<String> parts = fullName.trim().split('\\s+');
    if (parts.isEmpty()) {
      return 'NA';
    }
    String firstInitial = parts[0].left(1).toUpperCase();
    String lastInitial = parts.size() > 1
      ? parts[parts.size() - 1].left(1).toUpperCase()
      : '';
    return firstInitial + lastInitial;
  }

  private static List<PolicySummary> fetchPoliciesForAccount(Id accountId) {
    List<PolicySummary> policies = new List<PolicySummary>();
    if (accountId == null) {
      return policies;
    }

    Map<String, Schema.SObjectType> objectTypesByName = Schema.getGlobalDescribe();
    if (objectTypesByName.containsKey('InsurancePolicy__c')) {
      policies = queryPolicyObject('InsurancePolicy__c', 'Account__c', accountId);
      if (!policies.isEmpty()) {
        return policies;
      }
    }
    if (objectTypesByName.containsKey('Policy__c')) {
      policies = queryPolicyObject('Policy__c', 'Account__c', accountId);
      if (!policies.isEmpty()) {
        return policies;
      }
    }
    if (objectTypesByName.containsKey('Contract')) {
      policies = queryPolicyObject('Contract', 'AccountId', accountId);
    }
    return policies;
  }

  private static List<PolicySummary> queryPolicyObject(
    String objectApiName,
    String accountFieldApiName,
    Id accountId
  ) {
    List<PolicySummary> policies = new List<PolicySummary>();
    try {
      Schema.DescribeSObjectResult objectDescribe = Schema.getGlobalDescribe()
        .get(objectApiName)
        .getDescribe();
      Map<String, Schema.SObjectField> fieldsByName = objectDescribe.fields.getMap();

      String nameField = chooseField(fieldsByName, new List<String>{
        'Name',
        'PolicyNumber__c',
        'ContractNumber'
      });
      String statusField = chooseField(fieldsByName, new List<String>{
        'Status__c',
        'Policy_Status__c',
        'Status'
      });
      String amountField = chooseField(fieldsByName, new List<String>{
        'Premium__c',
        'Annual_Premium__c',
        'Amount__c',
        'TotalPrice'
      });
      String renewalField = chooseField(fieldsByName, new List<String>{
        'Renewal_Date__c',
        'Expiration_Date__c',
        'EndDate'
      });

      List<String> selectedFields = new List<String>{ 'Id', accountFieldApiName };
      if (!String.isBlank(nameField)) selectedFields.add(nameField);
      if (!String.isBlank(statusField)) selectedFields.add(statusField);
      if (!String.isBlank(amountField)) selectedFields.add(amountField);
      if (!String.isBlank(renewalField)) selectedFields.add(renewalField);

      String soql =
        'SELECT ' +
        String.join(selectedFields, ', ') +
        ' FROM ' +
        objectApiName +
        ' WHERE ' +
        accountFieldApiName +
        ' = :accountId LIMIT 5';
      List<SObject> records = Database.query(soql);

      for (SObject recordItem : records) {
        PolicySummary policy = new PolicySummary();
        policy.name = asString(recordItem.get(nameField), 'Policy');
        policy.statusLabel = asString(recordItem.get(statusField), 'Unknown');
        policy.amountLabel = asMoney(recordItem.get(amountField));
        policy.renewalDateLabel = asDateLabel(recordItem.get(renewalField));
        policies.add(policy);
      }
    } catch (Exception ex) {
      // keep graceful fallback behavior for orgs without policy data model access
      return new List<PolicySummary>();
    }
    return policies;
  }

  private static List<PolicySummary> derivePoliciesFromOpportunities(
    List<OpportunitySummary> opportunities
  ) {
    List<PolicySummary> policies = new List<PolicySummary>();
    for (OpportunitySummary opportunity : opportunities) {
      PolicySummary policy = new PolicySummary();
      policy.name = opportunity.name;
      policy.statusLabel = opportunity.stageName;
      policy.amountLabel = opportunity.amountLabel;
      policy.renewalDateLabel = opportunity.closeDateLabel;
      policies.add(policy);
    }
    return policies;
  }

  private static String chooseField(
    Map<String, Schema.SObjectField> fieldsByName,
    List<String> candidates
  ) {
    for (String candidate : candidates) {
      if (fieldsByName.containsKey(candidate)) {
        return candidate;
      }
    }
    return null;
  }

  private static String asString(Object value, String fallback) {
    if (value == null) {
      return fallback;
    }
    String output = String.valueOf(value);
    return String.isBlank(output) ? fallback : output;
  }

  private static String asMoney(Object value) {
    if (value == null) {
      return 'N/A';
    }
    try {
      Decimal amount = Decimal.valueOf(String.valueOf(value));
      return '$' + String.valueOf(amount.setScale(0));
    } catch (Exception ex) {
      return String.valueOf(value);
    }
  }

  private static String asDateLabel(Object value) {
    if (value == null) {
      return 'TBD';
    }
    if (value instanceof Date) {
      return ((Date) value).format();
    }
    if (value instanceof Datetime) {
      return ((Datetime) value).format('MMM d, yyyy');
    }
    return String.valueOf(value);
  }
}
