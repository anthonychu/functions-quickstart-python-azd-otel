# TypeScript vs Python Implementation Comparison

This document highlights the key differences between the Python and TypeScript implementations of the Azure Functions quickstart.

## Directory Structure

### Python (`src/`)
- `function_app.py` - All functions in a single file
- `requirements.txt` - Python dependencies
- `host.json` - Function host configuration
- `local.settings.json.template` - Local settings template

### TypeScript (`src-ts/`)
- `src/index.ts` - Function registration
- `src/functions/firstHttpFunction.ts` - First HTTP function
- `src/functions/secondHttpFunction.ts` - Second HTTP function with Service Bus output
- `src/functions/serviceBusQueueTrigger.ts` - Service Bus trigger
- `package.json` - Node.js dependencies
- `tsconfig.json` - TypeScript configuration
- `host.json` - Function host configuration
- `local.settings.json.template` - Local settings template

## Key Code Differences

### Function Registration

**Python (v2 model):**
```python
app = func.FunctionApp()

@app.function_name("first_http_function")
@app.route(route="first_http_function", auth_level=func.AuthLevel.ANONYMOUS)
def first_http_function(req: func.HttpRequest) -> func.HttpResponse:
    # ...
```

**TypeScript (v4 model):**
```typescript
import { app } from '@azure/functions';

app.http('first_http_function', {
    methods: ['GET', 'POST'],
    authLevel: 'anonymous',
    route: 'first_http_function',
    handler: firstHttpFunction
});
```

### Service Bus Output Binding

**Python:**
```python
@app.service_bus_queue_output(arg_name="outputsbmsg", queue_name="%ServiceBusQueueName%",
                              connection="ServiceBusConnection")
def second_http_function(req: func.HttpRequest, outputsbmsg: func.Out[str]) -> func.HttpResponse:
    outputsbmsg.set(queue_message)
```

**TypeScript:**
```typescript
const serviceBusOutput = output.serviceBusQueue({
    queueName: '%ServiceBusQueueName%',
    connection: 'ServiceBusConnection'
});

export async function secondHttpFunction(request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> {
    context.extraOutputs.set(serviceBusOutput, queueMessage);
}
```

### Service Bus Queue Trigger

**Python:**
```python
@app.service_bus_queue_trigger(arg_name="azservicebus", queue_name="%ServiceBusQueueName%",
                               connection="ServiceBusConnection") 
def servicebus_queue_trigger(azservicebus: func.ServiceBusMessage):
    logging.info('Python ServiceBus Queue trigger...')
```

**TypeScript:**
```typescript
app.serviceBusQueue('servicebus_queue_trigger', {
    queueName: '%ServiceBusQueueName%',
    connection: 'ServiceBusConnection',
    handler: serviceBusQueueTrigger
});
```

## Infrastructure Differences

### Runtime Configuration

**Python (main.bicep):**
```bicep
runtimeName: 'python'
runtimeVersion: '3.12'
```

**TypeScript (main.bicep):**
```bicep
runtimeName: 'node'
runtimeVersion: '20'
```

### Local Settings

**Python:**
```json
"FUNCTIONS_WORKER_RUNTIME": "python"
```

**TypeScript:**
```json
"FUNCTIONS_WORKER_RUNTIME": "node"
```

## Build Process

### Python
- No build step required
- Direct deployment of source files

### TypeScript
```bash
npm install
npm run build  # Compiles TypeScript to JavaScript
```

## Common Features

Both implementations share:
- OpenTelemetry distributed tracing configuration in `host.json`
- Service Bus integration with managed identity
- Virtual network security support
- Same Azure infrastructure (Storage, Service Bus, App Insights)
- Same distributed tracing flow: HTTP → HTTP → Service Bus → Queue Trigger
