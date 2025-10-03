import { HttpRequest, HttpResponseInit, InvocationContext, output } from '@azure/functions';

// Define the service bus output binding for use in this function
const serviceBusOutput = output.serviceBusQueue({
    queueName: '%ServiceBusQueueName%',
    connection: 'ServiceBusConnection'
});

export async function secondHttpFunction(request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> {
    context.log('TypeScript HTTP trigger function (second) processed a request.');

    const message = 'This is the second function responding.';
    
    // Send a message to the Service Bus queue via output binding
    const queueMessage = 'Message from second HTTP function to trigger ServiceBus queue processing';
    context.extraOutputs.set(serviceBusOutput, queueMessage);
    context.log('Sent message to ServiceBus queue:', queueMessage);
    
    return {
        status: 200,
        body: message
    };
}



