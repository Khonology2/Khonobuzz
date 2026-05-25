namespace MyApi.DTOs.Auth
{
    /// <summary>
    /// Request body for POST /validate-token. Matches Python: { "token": "..." }.
    /// </summary>
    public class TokenValidationRequest
    {
        public string? Token { get; set; }
    }
}
