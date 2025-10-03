import { InvocationContext } from '@azure/functions';

export async function serviceBusQueueTrigger(message: unknown, context: InvocationContext): Promise<void> {
    const messageBody = typeof message === 'string' ? message : JSON.stringify(message);
    
    context.log('TypeScript ServiceBus Queue trigger start processing a message:', messageBody);
    
    // Simulate processing work with a 5-second delay
    await new Promise(resolve => setTimeout(resolve, 5000));
    
    context.log('TypeScript ServiceBus Queue trigger end processing a message');
}
