---
description: This TypeScript sample demonstrates distributed tracing with OpenTelemetry across multiple Azure Functions in a Flex Consumption plan app with Service Bus integration and virtual network security.
page_type: sample
products:
- azure-functions
- azure
urlFragment: functions-quickstart-typescript-azd-otel
languages:
- typescript
- bicep
- azdeveloper
---

# Azure Functions TypeScript Service Bus Trigger with OpenTelemetry Distributed Tracing using Azure Developer CLI

This is the TypeScript version of the Azure Functions quickstart template. It demonstrates distributed tracing using OpenTelemetry across multiple Azure Functions and includes managed identity and virtual network integration for secure deployment by default.

## Key Features

* **Distributed tracing with OpenTelemetry**. The sample shows how to trace requests across multiple Azure Functions using OpenTelemetry integration, providing end-to-end visibility into function execution flows.
* **Virtual network integration**. The Service Bus that this Flex Consumption app reads events from is secured behind a private endpoint. The function app can read events from it because it is configured with VNet integration.
* **Azure Functions v4 Programming Model**. Uses the latest TypeScript v4 programming model for Azure Functions.

## Prerequisites

+ [Node.js 20.x](https://nodejs.org/)
+ [Azure Functions Core Tools v4](https://learn.microsoft.com/azure/azure-functions/functions-run-local?tabs=v4%2Clinux%2Cnode%2Cportal%2Cbash#install-the-azure-functions-core-tools)
+ To use Visual Studio Code to run and debug locally:
  + [Visual Studio Code](https://code.visualstudio.com/)
  + [Azure Functions extension](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-azurefunctions)
+ [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) (for deployment)
+ [Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd)
+ An Azure subscription with Microsoft.Web and Microsoft.App [registered resource providers](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-providers-and-types#register-resource-provider)

## Prepare your local environment

1. Navigate to the `src-ts` folder and install dependencies:

    ```shell
    cd src-ts
    npm install
    ```

2. Create a `local.settings.json` file from the template:

    ```shell
    cp local.settings.json.template local.settings.json
    ```

    The `ServiceBusConnection` will be empty for local development. You'll need an actual Service Bus connection for full testing, which will be provided after deployment to Azure.

3. Build the TypeScript code:

    ```shell
    npm run build
    ```

## Run your app from the terminal

1. From the `src-ts` folder, run this command to start the Functions host locally:

    ```shell
    func start
    ```

    > [!NOTE]
    > The Service Bus trigger function will start but won't process messages until connected to an actual Service Bus queue. However, you can test the HTTP functions locally.

2. The function will start and display the available functions:

    ```
    Functions:
        first_http_function: [GET,POST] http://localhost:7071/api/first_http_function
        second_http_function: [GET,POST] http://localhost:7071/api/second_http_function
        servicebus_queue_trigger: serviceBusQueueTrigger
    ```

3. You can test the HTTP functions locally by calling the endpoint.

4. When you're done, press Ctrl+C in the terminal window to stop the `func` host process.

## Source Code

The function app is defined in [`src-ts/src/index.ts`](./src-ts/src/index.ts) and registers three functions:

### 1. First HTTP Function
Located in [`src/functions/firstHttpFunction.ts`](./src-ts/src/functions/firstHttpFunction.ts), this function receives an HTTP request and calls the second HTTP function.

### 2. Second HTTP Function
Located in [`src/functions/secondHttpFunction.ts`](./src-ts/src/functions/secondHttpFunction.ts), this function responds to HTTP requests and sends a message to Service Bus using an output binding.

### 3. Service Bus Queue Trigger
Located in [`src/functions/serviceBusQueueTrigger.ts`](./src-ts/src/functions/serviceBusQueueTrigger.ts), this function is triggered by messages in the Service Bus queue and simulates processing with a 5-second delay.

### Distributed Tracing Flow
This architecture creates a complete distributed tracing scenario:
1. **First HTTP function** receives an HTTP request and calls the second HTTP function
2. **Second HTTP function** responds and sends a message to Service Bus
3. **Service Bus trigger** processes the message with a 5-second delay to simulate processing work

Key aspects of the implementation:

+ **OpenTelemetry integration**: The `host.json` file enables OpenTelemetry with `"telemetryMode": "OpenTelemetry"`
+ **Function chaining**: The first function calls the second using HTTP requests
+ **Service Bus integration**: The second function outputs to Service Bus, which triggers the third function
+ **Managed identity**: All Service Bus connections use managed identity instead of connection strings
+ **v4 Programming Model**: Uses the latest TypeScript programming model for Azure Functions

## Deploy to Azure

Run this command to provision the function app, with any required Azure resources, and deploy your code:

```shell
azd up
```

You're prompted to supply these required deployment parameters:

| Parameter | Description |
| ---- | ---- |
| _Environment name_ | An environment that's used to maintain a unique deployment context for your app. |
| _Azure subscription_ | Subscription in which your resources are created. |
| _Azure location_ | Azure region in which to create the resource group that contains the new Azure resources. Only regions that currently support the Flex Consumption plan are shown. |

After deployment completes successfully, `azd` provides you with the URL endpoints and resource information for your new function app.

## Test the solution

1. Once deployment is complete, you can test the distributed tracing functionality by calling the `first_http_function`:

2. **Call the first HTTP function**: Use the function URL provided after deployment:
   ```
   https://your-function-app.azurewebsites.net/api/first_http_function
   ```

3. **View distributed tracing in Application Insights**: 
   - Navigate to your Application Insights resource in the Azure Portal
   - Open the "Application map" to see the distributed trace across all three functions
   - Check the "Transaction search" to find your request and see the complete trace timeline
   - The trace will show: HTTP request → first_http_function → second_http_function → Service Bus message → servicebus_queue_trigger

## Clean up resources

When you're done working with your function app and related resources, you can use this command to delete the function app and its related resources from Azure:

```shell
azd down
```

## Resources

For more information, see:

* [Azure Functions TypeScript developer guide](https://learn.microsoft.com/azure/azure-functions/functions-reference-node?tabs=typescript%2Clinux%2Cazure-cli&pivots=nodejs-model-v4)
* [Azure Functions documentation](https://docs.microsoft.com/azure/azure-functions/)
* [OpenTelemetry in Azure Functions](https://learn.microsoft.com/azure/azure-functions/opentelemetry)
