import { HttpRequest, HttpResponseInit, InvocationContext } from '@azure/functions';

export async function firstHttpFunction(request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> {
    context.log('TypeScript HTTP trigger function (first) processed a request.');
    
    try {
        // Call the second function
        const baseUrl = request.url.split('/api/')[0];
        const secondFunctionUrl = `${baseUrl}/api/second_http_function`;
        
        const response = await fetch(secondFunctionUrl);
        const secondFunctionResult = await response.text();
        
        const result = {
            message: 'Hello from the first function!',
            second_function_response: secondFunctionResult
        };
        
        return {
            status: 200,
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(result)
        };
    } catch (error) {
        context.error('Error calling second function:', error);
        return {
            status: 500,
            body: JSON.stringify({ error: 'Failed to call second function' })
        };
    }
}
