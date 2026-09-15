@IsTest
private class AgentforceServiceTest {
  private class SuccessInvoker implements AgentforceService.AgentInvoker {
    public AgentforceService.InvocationResult invoke(
      String agentApiName,
      String userMessage,
      String sessionId
    ) {
      AgentforceService.InvocationResult result = new AgentforceService.InvocationResult();
      result.responseText = 'You currently have **14** open opportunities.';
      result.sessionId = String.isBlank(sessionId) ? 'SESSION-001' : sessionId;
      result.requestId = 'REQ-001';
      result.citations = new List<AgentforceService.Citation>();
      AgentforceService.Citation citation = new AgentforceService.Citation();
      citation.id = 'CIT-1';
      citation.title = 'Opportunities';
      citation.url = 'https://example.com/opps';
      citation.snippet = 'Open opportunity summary';
      citation.sourceType = 'record';
      result.citations.add(citation);
      return result;
    }
  }

  private class ErrorInvoker implements AgentforceService.AgentInvoker {
    private String message;

    ErrorInvoker(String message) {
      this.message = message;
    }

    public AgentforceService.InvocationResult invoke(
      String agentApiName,
      String userMessage,
      String sessionId
    ) {
      throw new AgentforceService.AgentforceServiceException(message);
    }
  }

  @IsTest
  static void sendMessage_createsNewSessionWhenMissing() {
    AgentforceService.invoker = new SuccessInvoker();

    Test.startTest();
    AgentforceService.AgentResponse response = AgentforceService.sendMessage(
      'Support_Agent',
      'Hello',
      null
    );
    Test.stopTest();

    System.assertNotEquals(null, response);
    System.assertNotEquals(null, response.message);
    System.assertEquals('assistant', response.message.role);
    System.assertEquals('SESSION-001', response.sessionId);
    System.assertEquals('REQ-001', response.requestId);
    System.assertEquals(1, response.citations.size());
  }

  @IsTest
  static void sendMessage_reusesExistingSession() {
    AgentforceService.invoker = new SuccessInvoker();

    AgentforceService.AgentResponse response = AgentforceService.sendMessage(
      'Support_Agent',
      'Continue conversation',
      'SESSION-EXISTING'
    );

    System.assertEquals('SESSION-EXISTING', response.sessionId);
  }

  @IsTest
  static void sendMessage_throwsForBlankAgent() {
    String code = AgentforceService.deriveErrorCode(
      'INVALID_INPUT: agentApiName is required.'
    );
    System.assertNotEquals(null, code);
  }

  @IsTest
  static void sendMessage_throwsForBlankMessage() {
    String code = AgentforceService.deriveErrorCode(
      'INVALID_INPUT: message is required.'
    );
    System.assertNotEquals(null, code);
  }

  @IsTest
  static void sendMessage_mapsInvalidAgentError() {
    String code = AgentforceService.deriveErrorCode('invalid agent');
    System.assertNotEquals(null, code);
  }

  @IsTest
  static void sendMessage_mapsPermissionError() {
    String code = AgentforceService.deriveErrorCode('permission denied');
    System.assertNotEquals(null, code);
  }

  @IsTest
  static void sendMessage_mapsTimeoutError() {
    String code = AgentforceService.deriveErrorCode('timeout while invoking');
    System.assertNotEquals(null, code);
    System.assertNotEquals(null, AgentforceService.isRetryableCode(code));
  }

  @IsTest
  static void buildActionInputs_includesExpectedFields() {
    Map<String, Object> payload = AgentforceService.buildActionInputs(
      'Support_Agent',
      'Hello',
      'SESSION-1'
    );
    System.assertNotEquals(null, payload);
    System.assert(payload.containsKey('inputs'));

    List<Object> inputs = (List<Object>) payload.get('inputs');
    System.assertEquals(1, inputs.size());
    Map<String, Object> first = (Map<String, Object>) inputs[0];
    System.assertEquals('Support_Agent', first.get('agentName'));
    System.assertEquals('Hello', first.get('userMessage'));
    System.assertEquals('SESSION-1', first.get('sessionId'));
  }

  @IsTest
  static void extractOutputFromRestResponse_readsOutputValues() {
    String responseBody = '{"results":[{"isSuccess":true,"outputValues":{"response":"Hi","sessionId":"S1","requestId":"R1"}}]}';
    Map<String, Object> output = AgentforceService.extractOutputFromRestResponse(
      responseBody
    );
    System.assertEquals('Hi', output.get('response'));
    System.assertEquals('S1', output.get('sessionId'));
    System.assertEquals('R1', output.get('requestId'));
  }

  @IsTest
  static void parseAgentOutput_readsInformMessageValue() {
    String agentResponse =
      '{"type":"InformMessage","value":{"result":[{"value":{"account_summary":{"accountName":"Annie Dubois","healthScore":80},"error_message":null}}],"feedbackId":"fb-1","message":"Structured account summary.","citedReferences":[{"id":"c1","title":"Account","url":"https://example.com/account"}],"isContentSafe":true}}';
    Map<String, Object> output = new Map<String, Object>{
      'sessionId' => '01a0a3c8-e9e9-76b3-adb0-6f1724d0bcee',
      'agentResponse' => agentResponse
    };

    AgentforceService.ParsedAgentOutput parsed = AgentforceService.parseAgentOutput(
      output
    );

    System.assertEquals('Structured account summary.', parsed.responseText);
    System.assertNotEquals(null, parsed.valueJson);
    System.assertEquals(1, parsed.widgets.size());
    System.assertEquals('account_summary', parsed.widgets[0].name);
    System.assert(parsed.widgets[0].payloadJson.contains('Annie Dubois'));
    System.assertEquals(1, parsed.citations.size());
    System.assertEquals('Account', parsed.citations[0].title);
  }

  @IsTest
  static void parseAgentOutput_acceptsAlreadyParsedEnvelope() {
    Map<String, Object> output = new Map<String, Object>{
      'agentResponse' => new Map<String, Object>{
        'type' => 'InformMessage',
        'value' => new Map<String, Object>{
          'message' => 'Parsed envelope.',
          'result' => new List<Object>{
            new Map<String, Object>{
              'value' => new Map<String, Object>{
                'account_summary' => new Map<String, Object>{
                  'accountName' => 'Annie Dubois'
                }
              }
            }
          }
        }
      }
    };

    AgentforceService.ParsedAgentOutput parsed = AgentforceService.parseAgentOutput(
      output
    );

    System.assertEquals('Parsed envelope.', parsed.responseText);
    System.assertEquals(1, parsed.widgets.size());
    System.assertEquals('account_summary', parsed.widgets[0].name);
    System.assert(parsed.widgets[0].payloadJson.contains('Annie Dubois'));
  }

  @IsTest
  static void parseAgentOutput_extractsDynamicWidgetKey() {
    Map<String, Object> output = new Map<String, Object>{
      'agentResponse' => new Map<String, Object>{
        'type' => 'InformMessage',
        'value' => new Map<String, Object>{
          'message' => 'Generic widget.',
          'result' => new List<Object>{
            new Map<String, Object>{
              'value' => new Map<String, Object>{
                'generic_section' => new Map<String, Object>{
                  'title' => 'Portfolio'
                },
                'error_message' => null
              }
            }
          }
        }
      }
    };

    AgentforceService.ParsedAgentOutput parsed = AgentforceService.parseAgentOutput(
      output
    );

    System.assertEquals(1, parsed.widgets.size());
    System.assertEquals('generic_section', parsed.widgets[0].name);
    System.assert(parsed.widgets[0].payloadJson.contains('Portfolio'));
  }

  @IsTest
  static void sendMessage_returnsInformMessageValueJson() {
    AgentforceService.invoker = new ValueInvoker();

    AgentforceService.AgentResponse response = AgentforceService.sendMessage(
      'SearchAgent',
      'Summarize Annie Dubois',
      null
    );

    System.assertEquals('Here is a structured summary.', response.message.content);
    System.assertNotEquals(null, response.valueJson);
    System.assertEquals(1, response.widgets.size());
    System.assertEquals('account_summary', response.widgets[0].name);
  }

  private class ValueInvoker implements AgentforceService.AgentInvoker {
    public AgentforceService.InvocationResult invoke(
      String agentApiName,
      String userMessage,
      String sessionId
    ) {
      AgentforceService.InvocationResult result = new AgentforceService.InvocationResult();
      result.responseText = 'Here is a structured summary.';
      result.sessionId = 'SESSION-VALUE';
      result.requestId = 'REQ-VALUE';
      result.citations = new List<AgentforceService.Citation>();
      result.valueJson = '{"result":[{"value":{"account_summary":{"accountName":"Annie Dubois"}}}],"message":"Here is a structured summary."}';
      AgentforceService.WidgetPayload widget = new AgentforceService.WidgetPayload();
      widget.name = 'account_summary';
      widget.payloadJson = '{"accountName":"Annie Dubois"}';
      result.widgets = new List<AgentforceService.WidgetPayload>{ widget };
      return result;
    }
  }
}
