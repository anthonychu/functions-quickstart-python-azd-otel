using System.Net;
using System.Text.Json;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Azure.Functions.Worker.Http;
using Microsoft.Extensions.Logging;

namespace FunctionApp;

public class FirstHttpFunction
{
    private readonly ILogger<FirstHttpFunction> _logger;
    private readonly IHttpClientFactory _httpClientFactory;

    public FirstHttpFunction(ILogger<FirstHttpFunction> logger, IHttpClientFactory httpClientFactory)
    {
        _logger = logger;
        _httpClientFactory = httpClientFactory;
    }

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
}
