using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;

namespace FunctionApp;

public class ServiceBusQueueTrigger
{
    private readonly ILogger<ServiceBusQueueTrigger> _logger;

    public ServiceBusQueueTrigger(ILogger<ServiceBusQueueTrigger> logger)
    {
        _logger = logger;
    }

    [Function(nameof(ServiceBusQueueTrigger))]
    public async Task Run(
        [ServiceBusTrigger("%ServiceBusQueueName%", Connection = "ServiceBusConnection")] string message)
    {
        _logger.LogInformation("C# ServiceBus Queue trigger start processing a message: {Message}", message);
        await Task.Delay(5000);
        _logger.LogInformation("C# ServiceBus Queue trigger end processing a message");
    }
}
