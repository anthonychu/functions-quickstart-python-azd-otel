---
description: This end-to-end .NET sample demonstrates distributed tracing with OpenTelemetry across multiple Azure Functions in a Flex Consumption plan app with Service Bus integration and virtual network security.
page_type: sample
products:
- azure-functions
- azure
urlFragment: functions-quickstart-dotnet-azd-otel
languages:
- csharp
- bicep
- azdeveloper
---

# Azure Functions .NET Service Bus Trigger with OpenTelemetry Distributed Tracing using Azure Developer CLI

This template repository contains a Service Bus trigger reference sample for functions written in C# using .NET 8 isolated worker model and deployed to Azure using the Azure Developer CLI (`azd`). The sample demonstrates distributed tracing using OpenTelemetry across multiple Azure Functions and includes managed identity and virtual network integration for secure deployment by default. This sample demonstrates these key features:

* **Distributed tracing with OpenTelemetry**. The sample shows how to trace requests across multiple Azure Functions using OpenTelemetry integration, providing end-to-end visibility into function execution flows.
* **Virtual network integration**. The Service Bus that this Flex Consumption app reads events from is secured behind a private endpoint. The function app can read events from it because it is configured with VNet integration. All connections to Service Bus and to the storage account associated with the Flex Consumption app also use managed identity connections instead of connection strings.

![Diagram showing Service Bus with a private endpoint and an Azure Functions Flex Consumption app triggering from it via VNet integration](./img/SB-VNET.png)

This project is designed to run on your local computer. You can also use GitHub Codespaces if available.

This sample demonstrates distributed tracing across multiple Azure Functions with OpenTelemetry integration. The app includes three functions that work together: an HTTP-triggered function that calls a second HTTP function, which then sends a message to Service Bus that triggers a third function. This creates a complete end-to-end tracing scenario that you can observe in Application Insights.

> [!IMPORTANT]
> This sample creates several resources. Make sure to delete the resource group after testing to minimize charges!

## Prerequisites

+ [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)
+ [Azure Functions Core Tools](https://learn.microsoft.com/azure/azure-functions/functions-run-local?tabs=v4%2Clinux%2Ccsharp%2Cportal%2Cbash#install-the-azure-functions-core-tools)
+ To use Visual Studio Code to run and debug locally:
  + [Visual Studio Code](https://code.visualstudio.com/)
  + [Azure Functions extension](https://marketplace.visualstudio.com/items?itemName=ms-azuretools.vscode-azurefunctions)
  + [C# extension](https://marketplace.visualstudio.com/items?itemName=ms-dotnettools.csharp)
+ [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) (for deployment)
+ [Azure Developer CLI](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd?tabs=winget-windows%2Cbrew-mac%2Cscript-linux&pivots=os-windows)
+ An Azure subscription with Microsoft.Web and Microsoft.App [registered resource providers](https://learn.microsoft.com/azure/azure-resource-manager/management/resource-providers-and-types#register-resource-provider)

## Initialize the local project

You can initialize a project from this `azd` template in one of these ways:

+ Use this `azd init` command from an empty local (root) folder:

    ```shell
    azd init --template functions-quickstart-dotnet-azd-otel
    ```

    Supply an environment name, such as `flexquickstart` when prompted. In `azd`, the environment is used to maintain a unique deployment context for your app.

+ Clone the GitHub template repository locally using the `git clone` command:

    ```shell
    git clone https://github.com/Azure-Samples/functions-quickstart-dotnet-azd-otel.git
    cd functions-quickstart-dotnet-azd-otel
    ```

    You can also clone the repository from your own fork in GitHub.

## Prepare your local environment

1. Navigate to the `src` app folder and create a file in that folder named `local.settings.json` that contains this JSON data:

    ```json
    {
        "IsEncrypted": false,
        "Values": {
            "AzureWebJobsStorage": "UseDevelopmentStorage=true",
            "FUNCTIONS_WORKER_RUNTIME": "dotnet-isolated",
            "ServiceBusConnection": "",
            "ServiceBusQueueName": "testqueue"
        }
    }
    ```

    > [!NOTE]
    > The `ServiceBusConnection` will be empty for local development. You'll need an actual Service Bus connection for full testing, which will be provided after deployment to Azure.

2. Build the project:

    ```shell
    dotnet build src/FunctionApp.csproj
    ```

## Run your app from the terminal

1. From the `src` folder, run this command to start the Functions host locally:

    ```shell
    func start
    ```

    > [!NOTE]
    > The Service Bus trigger function will start but won't process messages until connected to an actual Service Bus queue. However, you can test the HTTP functions locally.

2. The function will start and display the available functions. You should see output similar to:

    ```
    Functions:
        first_http_function: [GET,POST] http://localhost:7071/api/first_http_function
        second_http_function: [GET,POST] http://localhost:7071/api/second_http_function
        servicebus_queue_trigger: serviceBusQueueTrigger
    ```

3. You can test the HTTP functions locally by calling the endpoint, though the Service Bus functionality requires deployment to Azure for full testing.

4. When you're done, press Ctrl+C in the terminal window to stop the `func` host process.

## Run your app using Visual Studio Code

1. Open the project root folder in Visual Studio Code.
2. Open the `src` folder in the terminal within VS Code.
3. Press **Run/Debug (F5)** to run in the debugger. 
4. The Azure Functions extension will automatically detect your function and start the local runtime.
5. The function will start and be ready to receive Service Bus messages (though local testing requires an actual Service Bus connection).

## Source Code

The function app is defined in the `src` folder and contains three functions that demonstrate distributed tracing across a complete request flow:

### 1. First HTTP Function
[`src/FirstHttpFunction.cs`](./src/FirstHttpFunction.cs)
```csharp
[Function("first_http_function")]
public async Task<HttpResponseData> Run(
    [HttpTrigger(AuthorizationLevel.Anonymous, "get", "post", Route = "first_http_function")] HttpRequestData req)
{
    _logger.LogInformation("C# HTTP trigger function (first) processed a request.");

    // Call the second function
    var baseUrl = $"{req.Url.Scheme}://{req.Url.Authority}/api";
    var secondFunctionUrl = $"{baseUrl}/second_http_function";

    var httpClient = _httpClientFactory.CreateClient();
    var response = await httpClient.GetAsync(secondFunctionUrl);
    var secondFunctionResult = await response.Content.ReadAsStringAsync();

    var result = new
    {
        message = "Hello from the first function!",
        second_function_response = secondFunctionResult
    };

    var httpResponse = req.CreateResponse(HttpStatusCode.OK);
    httpResponse.Headers.Add("Content-Type", "application/json");
    await httpResponse.WriteStringAsync(JsonSerializer.Serialize(result));

    return httpResponse;
}
```

### 2. Second HTTP Function
[`src/SecondHttpFunction.cs`](./src/SecondHttpFunction.cs)
```csharp
[Function("second_http_function")]
public async Task<OutputType> Run(
    [HttpTrigger(AuthorizationLevel.Anonymous, "get", "post", Route = "second_http_function")] HttpRequestData req)
{
    _logger.LogInformation("C# HTTP trigger function (second) processed a request.");

    var message = "This is the second function responding.";

    // Send a message to the Service Bus queue
    var queueMessage = "Message from second HTTP function to trigger ServiceBus queue processing";
    _logger.LogInformation("Sent message to ServiceBus queue: {Message}", queueMessage);

    var httpResponse = req.CreateResponse(HttpStatusCode.OK);
    httpResponse.Headers.Add("Content-Type", "text/plain");
    await httpResponse.WriteStringAsync(message);

    return new OutputType
    {
        HttpResponse = httpResponse,
        ServiceBusMessage = queueMessage
    };
}

public class OutputType
{
    [ServiceBusOutput("%ServiceBusQueueName%", Connection = "ServiceBusConnection")]
    public string? ServiceBusMessage { get; set; }

    public HttpResponseData? HttpResponse { get; set; }
}
```

### 3. Service Bus Queue Trigger
[`src/ServiceBusQueueTrigger.cs`](./src/ServiceBusQueueTrigger.cs)
```csharp
[Function(nameof(ServiceBusQueueTrigger))]
public async Task Run(
    [ServiceBusTrigger("%ServiceBusQueueName%", Connection = "ServiceBusConnection")] string message)
{
    _logger.LogInformation("C# ServiceBus Queue trigger start processing a message: {Message}", message);
    await Task.Delay(5000);
    _logger.LogInformation("C# ServiceBus Queue trigger end processing a message");
}
```

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
+ **Processing simulation**: The 5-second delay in the Service Bus trigger simulates message processing work

The function configuration in [`src/host.json`](./src/host.json) enables OpenTelemetry and configures Service Bus settings:

```json
{
  "version": "2.0",
  "telemetryMode": "OpenTelemetry",
  "logging": {
    "applicationInsights": {
      "samplingSettings": {
        "isEnabled": true,
        "maxTelemetryItemsPerSecond": 20
      }
    }
  },
  "extensions": {
    "serviceBus": {
      "maxConcurrentCalls": 10
    }
  }
}
```

Key configuration aspects:
+ **OpenTelemetry**: `"telemetryMode": "OpenTelemetry"` enables distributed tracing across function calls
+ **Service Bus concurrency**: `maxConcurrentCalls: 10` allows multiple messages to be processed concurrently
+ **Dependencies**: The project uses NuGet packages including `Microsoft.Azure.Functions.Worker.ApplicationInsights` and `Microsoft.Azure.Functions.Worker.Extensions.ServiceBus` for tracing and Service Bus integration

## Deploy to Azure

Run this command to provision the function app, with any required Azure resources, and deploy your code:

```shell
azd up
```

You're prompted to supply these required deployment parameters:

| Parameter | Description |
| ---- | ---- |
| _Environment name_ | An environment that's used to maintain a unique deployment context for your app. You won't be prompted if you created the local project using `azd init`. |
| _Azure subscription_ | Subscription in which your resources are created. |
| _Azure location_ | Azure region in which to create the resource group that contains the new Azure resources. Only regions that currently support the Flex Consumption plan are shown. |

After deployment completes successfully, `azd` provides you with the URL endpoints and resource information for your new function app.

## Test the solution

1. Once deployment is complete, you can test the distributed tracing functionality by calling the `first_http_function`:

2. **Call the first HTTP function**: Use the function URL provided after deployment to trigger the complete distributed tracing flow:
   ```
   https://your-function-app.azurewebsites.net/api/first_http_function
   ```

3. **View distributed tracing in Application Insights**: 
   - Navigate to your Application Insights resource in the Azure Portal
   - Open the "Application map" to see the distributed trace across all three functions
   - Check the "Transaction search" to find your request and see the complete trace timeline
   - The trace will show: HTTP request → first_http_function → second_http_function → Service Bus message → servicebus_queue_trigger

The Application Insights telemetry will show the complete distributed trace:
- The HTTP request to `first_http_function`
- The internal HTTP call to `second_http_function` 
- The Service Bus message being sent
- The `servicebus_queue_trigger` processing the message through the VNet-secured Service Bus

This demonstrates end-to-end distributed tracing across multiple Azure Functions with OpenTelemetry integration.

## Redeploy your code

You can run the `azd up` command as many times as you need to both provision your Azure resources and deploy code updates to your function app.

> [!NOTE]
> Deployed code files are always overwritten by the latest deployment package.

## Clean up resources

When you're done working with your function app and related resources, you can use this command to delete the function app and its related resources from Azure and avoid incurring any further costs:

```shell
azd down
```

## Resources

For more information on Azure Functions, Service Bus, OpenTelemetry, and VNet integration, see the following resources:

* [Azure Functions documentation](https://docs.microsoft.com/azure/azure-functions/)
* [Azure Service Bus documentation](https://docs.microsoft.com/azure/service-bus/)
* [Azure Virtual Network documentation](https://docs.microsoft.com/azure/virtual-network/)
* [OpenTelemetry in Azure Functions](https://learn.microsoft.com/azure/azure-functions/opentelemetry)
* [Application Insights and distributed tracing](https://learn.microsoft.com/azure/azure-monitor/app/distributed-tracing)
