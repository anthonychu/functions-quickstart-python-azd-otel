import { app, output } from '@azure/functions';
import { firstHttpFunction } from './functions/firstHttpFunction';
import { secondHttpFunction } from './functions/secondHttpFunction';
import { serviceBusQueueTrigger } from './functions/serviceBusQueueTrigger';

// Register all functions
app.http('first_http_function', {
    methods: ['GET', 'POST'],
    authLevel: 'anonymous',
    route: 'first_http_function',
    handler: firstHttpFunction
});

app.http('second_http_function', {
    methods: ['GET', 'POST'],
    authLevel: 'anonymous',
    route: 'second_http_function',
    extraOutputs: [output.serviceBusQueue({
        queueName: '%ServiceBusQueueName%',
        connection: 'ServiceBusConnection',
        name: 'serviceBusOutput'
    })],
    handler: secondHttpFunction
});

app.serviceBusQueue('servicebus_queue_trigger', {
    queueName: '%ServiceBusQueueName%',
    connection: 'ServiceBusConnection',
    handler: serviceBusQueueTrigger
});
