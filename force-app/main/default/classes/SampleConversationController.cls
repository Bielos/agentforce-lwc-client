/**
 * Backing controller for the Sample Conversation Player LWC.
 *
 * Provides read/save access to a Sample_Conversation__c transcript and resolves
 * the linked Coworker_Skill__mdt content that seeds the agent when a conversation
 * is played.
 */
public with sharing class SampleConversationController {
  /**
   * Load a single sample conversation with the fields the player needs.
   *
   * @param recordId Sample_Conversation__c record Id.
   * @return The conversation record.
   */
  /**
   * List sample conversations for the batch player, most recent first.
   *
   * @return All accessible Sample_Conversation__c records with player fields.
   */
  @AuraEnabled
  public static List<Sample_Conversation__c> getConversations() {
    return [
      SELECT
        Id,
        Name,
        Transcript__c,
        Skill_API_Name__c,
        Agent_API_Name__c,
        Description__c,
        Last_Play_Duration__c,
        LastModifiedDate
      FROM Sample_Conversation__c
      WITH USER_MODE
      ORDER BY LastModifiedDate DESC
      LIMIT 500
    ];
  }

  @AuraEnabled(cacheable=true)
  public static Sample_Conversation__c getConversation(Id recordId) {
    return [
      SELECT
        Id,
        Name,
        Transcript__c,
        Skill_API_Name__c,
        Agent_API_Name__c,
        Description__c,
        Last_Play_Duration__c,
        LastModifiedDate
      FROM Sample_Conversation__c
      WHERE Id = :recordId
      WITH USER_MODE
      LIMIT 1
    ];
  }

  /**
   * Persist an updated transcript (and optionally the chosen agent) back to the
   * record.
   *
   * @param recordId Sample_Conversation__c record Id.
   * @param transcript Serialized multi-turn transcript to save.
   * @param agentApiName Agent API name chosen in the player; ignored when blank.
   * @return The updated conversation record.
   */
  @AuraEnabled
  public static Sample_Conversation__c saveTranscript(
    Id recordId,
    String transcript,
    String agentApiName,
    Decimal durationSeconds
  ) {
    Sample_Conversation__c record = new Sample_Conversation__c(
      Id = recordId,
      Transcript__c = transcript
    );
    if (String.isNotBlank(agentApiName)) {
      record.Agent_API_Name__c = agentApiName.trim();
    }
    if (durationSeconds != null) {
      record.Last_Play_Duration__c = durationSeconds;
    }
    update as user record;
    return getConversation(recordId);
  }

  /**
   * Insert sample conversations from a parsed JSON tree (or record array).
   *
   * @param records Records with Name and optional skill/agent/description/transcript.
   * @return Count created and per-row failures (partial success).
   */
  @AuraEnabled
  public static ImportResult importConversations(
    List<Sample_Conversation__c> records
  ) {
    ImportResult outcome = new ImportResult();
    outcome.created = 0;
    outcome.failures = new List<String>();
    if (records == null || records.isEmpty()) {
      throw userError('No sample conversations found in that file.');
    }

    List<Sample_Conversation__c> toInsert = new List<Sample_Conversation__c>();
    for (Sample_Conversation__c row : records) {
      if (row == null || String.isBlank(row.Name)) {
        continue;
      }
      Sample_Conversation__c rec = new Sample_Conversation__c(
        Name = row.Name.trim()
      );
      if (String.isNotBlank(row.Skill_API_Name__c)) {
        rec.Skill_API_Name__c = row.Skill_API_Name__c;
      }
      if (String.isNotBlank(row.Agent_API_Name__c)) {
        rec.Agent_API_Name__c = row.Agent_API_Name__c;
      }
      if (String.isNotBlank(row.Description__c)) {
        rec.Description__c = row.Description__c;
      }
      if (String.isNotBlank(row.Transcript__c)) {
        rec.Transcript__c = row.Transcript__c;
      }
      toInsert.add(rec);
    }
    if (toInsert.isEmpty()) {
      throw userError('No sample conversations found in that file.');
    }

    List<Database.SaveResult> results = Database.insert(
      toInsert,
      false,
      AccessLevel.USER_MODE
    );
    for (Integer i = 0; i < results.size(); i++) {
      if (results[i].isSuccess()) {
        outcome.created++;
      } else {
        String message = 'Unable to create this conversation.';
        List<Database.Error> errors = results[i].getErrors();
        if (!errors.isEmpty() && String.isNotBlank(errors[0].getMessage())) {
          message = errors[0].getMessage();
        }
        outcome.failures.add(toInsert[i].Name + ': ' + message);
      }
    }
    return outcome;
  }

  /**
   * Result of a JSON import: how many rows were created and which failed.
   */
  public class ImportResult {
    @AuraEnabled
    public Integer created;
    @AuraEnabled
    public List<String> failures;
  }

  private static AuraHandledException userError(String message) {
    AuraHandledException ex = new AuraHandledException(message);
    ex.setMessage(message);
    return ex;
  }

  /**
   * Resolve the Content of a Coworker Skill by its API name (DeveloperName).
   *
   * @param skillApiName DeveloperName of the Coworker_Skill__mdt.
   * @return The skill Content, or null when the name is blank or not found.
   */
  @AuraEnabled(cacheable=true)
  public static String getSkillContent(String skillApiName) {
    if (String.isBlank(skillApiName)) {
      return null;
    }
    List<Coworker_Skill__mdt> skills = [
      SELECT Content__c
      FROM Coworker_Skill__mdt
      WHERE DeveloperName = :skillApiName
      LIMIT 1
    ];
    return skills.isEmpty() ? null : skills[0].Content__c;
  }
}
