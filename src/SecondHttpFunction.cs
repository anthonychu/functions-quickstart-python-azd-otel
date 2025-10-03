using System.Net;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;

namespace FunctionApp;

public class SecondHttpFunction
{
    private readonly ILogger<SecondHttpFunction> _logger;

    public SecondHttpFunction(ILogger<SecondHttpFunction> logger)
    {
        _logger = logger;
    }

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
}
