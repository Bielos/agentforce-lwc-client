/**
 * Facade service for invoking Agentforce from Lightning Web Components.
 * This class validates client input, calls the supported Agentforce invocable action,
 * and returns a normalized response contract to the UI layer.
 */
public with sharing class AgentforceService {
  private static final Integer MAX_MESSAGE_LENGTH = 4000;
  private static final String ACTION_TYPE = 'generateAiAgentResponse';
  private static final String ACTION_NAME = 'generateAiAgentResponse';
  private static final Set<String> WIDGET_META_KEYS = new Set<String>{
    'error_message',
    'errorMessage',
    'is_success',
    'isSuccess',
    'error_type',
    'errorType'
  };

  /**
   * DTO that represents a chat message.
   */
  public class ChatMessage {
    @AuraEnabled
    public String id;
    @AuraEnabled
    public String role;
    @AuraEnabled
    public String content;
    @AuraEnabled
    public Datetime timestamp;
  }

  /**
   * DTO that represents an Agentforce citation.
   */
  public class Citation {
    @AuraEnabled
    public String id;
    @AuraEnabled
    public String title;
    @AuraEnabled
    public String url;
    @AuraEnabled
    public String snippet;
    @AuraEnabled
    public String sourceType;
    @AuraEnabled
    public Integer offsetStart;
    @AuraEnabled
    public Integer offsetEnd;
  }

  /**
   * Top-level response DTO returned to LWC.
   */
  public class AgentResponse {
    @AuraEnabled
    public ChatMessage message;
    @AuraEnabled
    public String sessionId;
    @AuraEnabled
    public String requestId;
    @AuraEnabled
    public List<Citation> citations;
    @AuraEnabled
    public String valueJson;
    @AuraEnabled
    public List<WidgetPayload> widgets;
    @AuraEnabled
    public String errorCode;
    @AuraEnabled
    public Boolean retryable;
  }

  /**
   * Agent definition metadata exposed to the LWC picker.
   */
  public class AgentDefinitionOption {
    @AuraEnabled
    public String agentId;
    @AuraEnabled
    public String agentApiName;
    @AuraEnabled
    public String label;
    @AuraEnabled
    public String description;
    @AuraEnabled
    public Datetime lastModifiedDate;
  }

  /**
   * Internal normalized invocation result.
   */
  public class InvocationResult {
    public String responseText;
    public String sessionId;
    public String requestId;
    public List<Citation> citations;
    public String valueJson;
    public List<WidgetPayload> widgets;
  }

  /**
   * Generic widget payload extracted from InformMessage.value.result.
   * The widget name is the dynamic output key (for example account_summary).
   */
  public class WidgetPayload {
    @AuraEnabled
    public String name;
    @AuraEnabled
    public String payloadJson;
  }

  /**
   * Parsed InformMessage envelope extracted from agentResponse.
   */
  public class ParsedAgentOutput {
    public String responseText;
    public String valueJson;
    public List<WidgetPayload> widgets = new List<WidgetPayload>();
    public List<Citation> citations = new List<Citation>();
  }

  /**
   * Strategy interface used to allow deterministic unit testing.
   */
  public interface AgentInvoker {
    InvocationResult invoke(
      String agentApiName,
      String userMessage,
      String sessionId
    );
  }

  /**
   * Default invoker that uses the supported invocable action mechanism.
   */
  public class DefaultAgentInvoker implements AgentInvoker {
    public InvocationResult invoke(
      String agentApiName,
      String userMessage,
      String sessionId
    ) {
      Invocable.Action action = Invocable.Action.createCustomAction(
        ACTION_TYPE,
        null,
        agentApiName,
        '1.1.0'
      );
      action.setInvocationParameter('userMessage', userMessage);
      if (!String.isBlank(sessionId)) {
        action.setInvocationParameter('sessionId', sessionId);
      }

      List<Invocable.Action.Result> actionResults = action.invoke();
      if (actionResults == null || actionResults.isEmpty()) {
        throw new AgentforceServiceException(
          'Agentforce invocation returned no result.'
        );
      }

      Invocable.Action.Result actionResult = actionResults[0];
      if (!actionResult.isSuccess()) {
        String invocationError = actionResult.getErrors() != null &&
          !actionResult.getErrors().isEmpty()
          ? actionResult.getErrors()[0].getMessage()
          : 'Agentforce invocation failed.';
        throw new AgentforceServiceException(invocationError);
      }

      Map<String, Object> output = actionResult.getOutputParameters();
      ParsedAgentOutput parsed = parseAgentOutput(output);
      InvocationResult normalized = new InvocationResult();
      normalized.responseText = parsed.responseText;
      normalized.valueJson = parsed.valueJson;
      normalized.widgets = parsed.widgets;
      normalized.sessionId = safeToString(output.get('sessionId'));
      normalized.requestId = safeToString(output.get('requestId'));
      normalized.citations = parsed.citations == null
        ? new List<Citation>()
        : parsed.citations;
      return normalized;
    }
  }

  public class AgentforceServiceException extends Exception {
  }

  @TestVisible
  private static AgentInvoker invoker = new DefaultAgentInvoker();

  /**
   * Invokes an Agentforce agent and returns a normalized response for UI clients.
   *
   * @param agentApiName Agent API name configured in Agentforce.
   * @param message User message content to send.
   * @param sessionId Existing session id, optional.
   * @return AgentResponse containing assistant message and session context.
   * @throws AuraHandledException when validation or invocation fails.
   */
  @AuraEnabled
  public static AgentResponse sendMessage(
    String agentApiName,
    String message,
    String sessionId
  ) {
    try {
      validateInput(agentApiName, message);

      InvocationResult result = invoker.invoke(
        agentApiName.trim(),
        message.trim(),
        String.isBlank(sessionId) ? null : sessionId.trim()
      );

      AgentResponse response = new AgentResponse();
      response.message = new ChatMessage();
      response.message.id = generateMessageId();
      response.message.role = 'assistant';
      response.message.content = String.isBlank(result.responseText)
        ? 'I was unable to generate a response.'
        : result.responseText;
      response.message.timestamp = Datetime.now();
      response.sessionId = result.sessionId;
      response.requestId = result.requestId;
      response.citations = result.citations == null
        ? new List<Citation>()
        : result.citations;
      response.valueJson = result.valueJson;
      response.widgets = result.widgets == null
        ? new List<WidgetPayload>()
        : result.widgets;
      response.retryable = false;
      return response;
    } catch (Exception ex) {
      throw toAuraHandledException(ex);
    }
  }

  /**
   * Returns agent definitions from BotDefinition metadata.
   *
   * @return List of configured agent definitions for picker UX.
   */
  @AuraEnabled(cacheable=true)
  public static List<AgentDefinitionOption> getConfiguredAgents() {
    List<BotDefinition> definitions = [
      SELECT
        Id,
        DeveloperName,
        MasterLabel,
        Description,
        LastModifiedDate,
        AgentType
      FROM BotDefinition
      WHERE AgentType = 'AgentforceEmployeeAgent'
      WITH USER_MODE
      ORDER BY LastModifiedDate DESC
      LIMIT 20
    ];

    List<AgentDefinitionOption> options = new List<AgentDefinitionOption>();
    for (BotDefinition definition : definitions) {
      AgentDefinitionOption option = new AgentDefinitionOption();
      option.agentId = (String) definition.Id;
      option.agentApiName = definition.DeveloperName;
      option.label = String.isBlank(definition.MasterLabel)
        ? definition.DeveloperName
        : definition.MasterLabel;
      option.description = definition.Description;
      option.lastModifiedDate = definition.LastModifiedDate;
      if (!String.isBlank(option.agentApiName)) {
        options.add(option);
      }
    }
    return options;
  }

  /**
   * Returns available Agentforce agent API names.
   *
   * @return Unique sorted list of available agent API names.
   */
  @AuraEnabled
  public static List<String> getConfiguredAgentApiNames() {
    Set<String> uniqueNames = new Set<String>();
    for (AgentDefinitionOption option : getConfiguredAgents()) {
      if (option != null && !String.isBlank(option.agentApiName)) {
        uniqueNames.add(option.agentApiName);
      }
    }
    List<String> names = new List<String>(uniqueNames);
    names.sort();
    return names;
  }

  @TestVisible
  private static Map<String, Object> buildActionInputs(
    String agentApiName,
    String userMessage,
    String sessionId
  ) {
    Map<String, Object> input = new Map<String, Object>{
      'agentName' => agentApiName,
      'userMessage' => userMessage
    };
    if (!String.isBlank(sessionId)) {
      input.put('sessionId', sessionId);
    }
    return new Map<String, Object>{ 'inputs' => new List<Object>{ input } };
  }

  @TestVisible
  private static Map<String, Object> extractOutputFromRestResponse(
    String responseBody
  ) {
    if (String.isBlank(responseBody)) {
      throw new AgentforceServiceException(
        'Agentforce invocation returned empty response.'
      );
    }

    Object raw = JSON.deserializeUntyped(responseBody);
    if (!(raw instanceof Map<String, Object>)) {
      throw new AgentforceServiceException(
        'Unexpected Agentforce response format.'
      );
    }

    Map<String, Object> body = (Map<String, Object>) raw;
    Object resultsObject = body.get('results');
    if (!(resultsObject instanceof List<Object>)) {
      throw new AgentforceServiceException(
        'Agentforce response missing results.'
      );
    }

    List<Object> results = (List<Object>) resultsObject;
    if (results.isEmpty() || !(results[0] instanceof Map<String, Object>)) {
      throw new AgentforceServiceException(
        'Agentforce response contains no result item.'
      );
    }

    Map<String, Object> firstResult = (Map<String, Object>) results[0];
    Object successValue = firstResult.get('isSuccess');
    if (successValue != null && !(Boolean) successValue) {
      String errorMessage = safeToString(firstResult.get('message'));
      if (String.isBlank(errorMessage)) {
        errorMessage = safeToString(firstResult.get('errorMessage'));
      }
      if (String.isBlank(errorMessage)) {
        errorMessage = 'Agentforce invocation failed.';
      }
      throw new AgentforceServiceException(errorMessage);
    }

    if (firstResult.get('outputValues') instanceof Map<String, Object>) {
      return (Map<String, Object>) firstResult.get('outputValues');
    }

    Map<String, Object> passthrough = new Map<String, Object>();
    if (firstResult.get('response') != null) {
      passthrough.put('response', firstResult.get('response'));
    }
    if (firstResult.get('agentResponse') != null) {
      passthrough.put('agentResponse', firstResult.get('agentResponse'));
    }
    if (firstResult.get('sessionId') != null) {
      passthrough.put('sessionId', firstResult.get('sessionId'));
    }
    if (firstResult.get('requestId') != null) {
      passthrough.put('requestId', firstResult.get('requestId'));
    }
    if (firstResult.get('citations') != null) {
      passthrough.put('citations', firstResult.get('citations'));
    }
    return passthrough;
  }

  @TestVisible
  private static void validateInput(String agentApiName, String message) {
    if (String.isBlank(agentApiName)) {
      throw new AgentforceServiceException(
        'INVALID_INPUT: agentApiName is required.'
      );
    }
    if (String.isBlank(message)) {
      throw new AgentforceServiceException(
        'INVALID_INPUT: message is required.'
      );
    }
    if (message.length() > MAX_MESSAGE_LENGTH) {
      throw new AgentforceServiceException(
        'INVALID_INPUT: message exceeds maximum length.'
      );
    }
  }

  @TestVisible
  private static AuraHandledException toAuraHandledException(Exception ex) {
    String message = ex == null ? 'Unknown error.' : ex.getMessage();
    String code = deriveErrorCode(message);
    Boolean retryable = isRetryableCode(code);

    String safeMessage = code + ': ' + userSafeMessage(code);
    if (retryable) {
      safeMessage += ' Please retry.';
    }

    return new AuraHandledException(safeMessage);
  }

  @TestVisible
  private static String deriveErrorCode(String message) {
    if (String.isBlank(message)) {
      return 'UNKNOWN_ERROR';
    }
    String lowered = message.toLowerCase();
    if (
      lowered.contains('invalid_agent') || lowered.contains('invalid agent')
    ) {
      return 'INVALID_AGENT';
    }
    if (lowered.contains('permission')) {
      return 'PERMISSION_DENIED';
    }
    if (lowered.contains('timeout')) {
      return 'TIMEOUT';
    }
    if (lowered.contains('session') && lowered.contains('expired')) {
      return 'SESSION_EXPIRED';
    }
    if (
      lowered.contains('limit') ||
      lowered.contains('too many') ||
      lowered.contains('governor')
    ) {
      return 'GOVERNOR_LIMIT';
    }
    if (lowered.contains('unavailable')) {
      return 'AGENT_UNAVAILABLE';
    }
    if (lowered.startsWith('invalid_input')) {
      return 'INVALID_INPUT';
    }
    return 'UNKNOWN_ERROR';
  }

  @TestVisible
  private static Boolean isRetryableCode(String code) {
    return code == 'TIMEOUT' ||
      code == 'SESSION_EXPIRED' ||
      code == 'GOVERNOR_LIMIT' ||
      code == 'AGENT_UNAVAILABLE';
  }

  @TestVisible
  private static String userSafeMessage(String code) {
    if (code == 'INVALID_INPUT') {
      return 'Please review your input and try again.';
    }
    if (code == 'INVALID_AGENT') {
      return 'The configured agent could not be found.';
    }
    if (code == 'PERMISSION_DENIED') {
      return 'You do not have permission to use this agent.';
    }
    if (code == 'TIMEOUT') {
      return 'The request timed out.';
    }
    if (code == 'SESSION_EXPIRED') {
      return 'The conversation session expired.';
    }
    if (code == 'GOVERNOR_LIMIT') {
      return 'The platform is temporarily busy.';
    }
    if (code == 'AGENT_UNAVAILABLE') {
      return 'The agent is currently unavailable.';
    }
    return 'Something went wrong while contacting the agent.';
  }

  @TestVisible
  private static String safeToString(Object value) {
    return value == null ? null : String.valueOf(value);
  }

  @TestVisible
  private static String resolveResponseText(Map<String, Object> output) {
    return parseAgentOutput(output).responseText;
  }

  /**
   * Parses generateAiAgentResponse output, including InformMessage.value.
   *
   * @param output Invocable action output parameters.
   * @return Parsed text, serialized value payload, and citations.
   */
  @TestVisible
  private static ParsedAgentOutput parseAgentOutput(Map<String, Object> output) {
    ParsedAgentOutput parsed = new ParsedAgentOutput();
    if (output == null) {
      return parsed;
    }

    parsed.responseText = blankToNull(safeToString(output.get('response')));
    parsed.citations = parseCitations(output.get('citations'));

    Map<String, Object> envelope = coerceToMap(output.get('agentResponse'));
    if (envelope == null) {
      return parsed;
    }

    Map<String, Object> valueMap = coerceToMap(envelope.get('value'));
    if (valueMap == null) {
      return parsed;
    }

    parsed.valueJson = JSON.serialize(valueMap);
    parsed.widgets = extractWidgets(valueMap);
    if (String.isBlank(parsed.responseText)) {
      parsed.responseText = blankToNull(safeToString(valueMap.get('message')));
    }
    if (parsed.citations.isEmpty()) {
      parsed.citations = parseCitations(valueMap.get('citedReferences'));
    }
    return parsed;
  }

  /**
   * Extracts dynamic widget payloads from InformMessage.value.result.
   * Each non-metadata key on a result value is treated as a widget name.
   *
   * @param valueMap InformMessage value object.
   * @return Widget payloads keyed by their dynamic output names.
   */
  @TestVisible
  private static List<WidgetPayload> extractWidgets(Map<String, Object> valueMap) {
    List<WidgetPayload> widgets = new List<WidgetPayload>();
    if (valueMap == null || !(valueMap.get('result') instanceof List<Object>)) {
      return widgets;
    }

    for (Object resultItem : (List<Object>) valueMap.get('result')) {
      Map<String, Object> resultMap = coerceToMap(resultItem);
      if (resultMap == null) {
        continue;
      }
      Map<String, Object> payload = coerceToMap(resultMap.get('value'));
      if (payload == null) {
        continue;
      }
      for (String key : payload.keySet()) {
        if (WIDGET_META_KEYS.contains(key) || payload.get(key) == null) {
          continue;
        }
        Object widgetValue = payload.get(key);
        if (
          !(widgetValue instanceof Map<String, Object>) &&
          !(widgetValue instanceof List<Object>)
        ) {
          continue;
        }
        WidgetPayload widget = new WidgetPayload();
        widget.name = key;
        widget.payloadJson = JSON.serialize(widgetValue);
        widgets.add(widget);
      }
    }
    return widgets;
  }

  @TestVisible
  private static Map<String, Object> coerceToMap(Object raw) {
    if (raw instanceof Map<String, Object>) {
      return (Map<String, Object>) raw;
    }
    if (!(raw instanceof String) || String.isBlank((String) raw)) {
      return null;
    }
    try {
      Object parsed = JSON.deserializeUntyped((String) raw);
      if (parsed instanceof Map<String, Object>) {
        return (Map<String, Object>) parsed;
      }
    } catch (Exception ex) {
      return null;
    }
    return null;
  }

  @TestVisible
  private static String blankToNull(String value) {
    return String.isBlank(value) ? null : value;
  }

  @TestVisible
  private static String generateMessageId() {
    return String.valueOf(Crypto.getRandomLong()).replace('-', '');
  }

  @TestVisible
  private static List<Citation> parseCitations(Object rawCitations) {
    List<Citation> parsed = new List<Citation>();
    if (rawCitations == null || !(rawCitations instanceof List<Object>)) {
      return parsed;
    }

    List<Object> values = (List<Object>) rawCitations;
    for (Object value : values) {
      if (!(value instanceof Map<String, Object>)) {
        continue;
      }
      Map<String, Object> rawCitation = (Map<String, Object>) value;
      Citation citation = new Citation();
      citation.id = safeToString(rawCitation.get('id'));
      citation.title = safeToString(rawCitation.get('title'));
      citation.url = safeToString(rawCitation.get('url'));
      citation.snippet = safeToString(rawCitation.get('snippet'));
      citation.sourceType = safeToString(rawCitation.get('sourceType'));
      citation.offsetStart = toInteger(rawCitation.get('offsetStart'));
      citation.offsetEnd = toInteger(rawCitation.get('offsetEnd'));
      parsed.add(citation);
    }
    return parsed;
  }

  @TestVisible
  private static Integer toInteger(Object value) {
    if (value == null) {
      return null;
    }
    try {
      return Integer.valueOf(String.valueOf(value));
    } catch (Exception ex) {
      return null;
    }
  }
}
