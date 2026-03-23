using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Cryptography;
using Microsoft.IdentityModel.Tokens;
using MyApi.Models;

namespace MyApi.Services
{
    public class TokenService : ITokenService
    {
        private readonly IConfiguration _configuration;

        public TokenService(IConfiguration configuration)
        {
            _configuration = configuration;
        }

        private string GetEncryptionKey()
        {
            var key = Environment.GetEnvironmentVariable("ENCRYPTION_KEY")?.Trim()
                ?? _configuration["Encryption:Key"]?.Trim();
            if (string.IsNullOrEmpty(key))
                throw new InvalidOperationException("ENCRYPTION_KEY or Encryption:Key not configured");
            return key;
        }

        public string GenerateToken(User user, IReadOnlyList<string>? roles = null)
        {
            var claimsList = new List<Claim>
            {
                new Claim(JwtRegisteredClaimNames.Sub, user.Id),
                new Claim(JwtRegisteredClaimNames.Email, user.Email),
                new Claim(JwtRegisteredClaimNames.Name, user.Name ?? ""),
                new Claim("department", user.Department ?? ""),
                new Claim("designation", user.Designation ?? ""),
                new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
            };
            if (roles != null && roles.Count > 0)
            {
                foreach (var r in roles)
                    claimsList.Add(new Claim(ClaimTypes.Role, r));
            }
            return CreateToken(claimsList);
        }

        public string GenerateTokenFromDict(string id, string email, string name, string department = "", string designation = "", IReadOnlyList<string>? roles = null)
        {
            var claimsList = new List<Claim>
            {
                new Claim(JwtRegisteredClaimNames.Sub, id),
                new Claim(JwtRegisteredClaimNames.Email, email),
                new Claim(JwtRegisteredClaimNames.Name, name ?? ""),
                new Claim("department", department ?? ""),
                new Claim("designation", designation ?? ""),
                new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
            };
            if (roles != null && roles.Count > 0)
            {
                foreach (var r in roles)
                    claimsList.Add(new Claim(ClaimTypes.Role, r));
            }
            return CreateToken(claimsList);
        }

        private string CreateToken(List<Claim> claims)
        {
            var secretKey = _configuration["Jwt:SecretKey"] ?? throw new InvalidOperationException("JWT SecretKey not configured");
            var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secretKey));
            var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);
            var expirationHours = _configuration.GetValue<int>("Jwt:ExpirationHours", 24);
            var token = new JwtSecurityToken(
                issuer: null,
                audience: null,
                claims: claims,
                expires: DateTime.UtcNow.AddHours(expirationHours),
                signingCredentials: creds);
            return new JwtSecurityTokenHandler().WriteToken(token);
        }

        public string EncryptToken(string plainJwt)
        {
            var key = GetEncryptionKey();
            return Fernet.Encrypt(key, plainJwt);
        }

        public string DecryptToken(string encryptedToken)
        {
            var key = GetEncryptionKey();
            return Fernet.Decrypt(key, encryptedToken);
        }

        public bool IsEncryptedToken(string token)
        {
            if (string.IsNullOrEmpty(token)) return false;
            return token.StartsWith("gAAAA", StringComparison.Ordinal) || !token.Contains('.');
        }

        public string? GetUserIdFromToken(string token)
        {
            try
            {
                var jwt = token;
                if (IsEncryptedToken(token))
                {
                    try { jwt = DecryptToken(token); } catch { return null; }
                }
                var tokenHandler = new JwtSecurityTokenHandler();
                var secretKey = _configuration["Jwt:SecretKey"] ?? throw new InvalidOperationException("JWT SecretKey not configured");
                var key = Encoding.UTF8.GetBytes(secretKey);

                var validationParameters = new TokenValidationParameters
                {
                    ValidateIssuerSigningKey = true,
                    IssuerSigningKey = new SymmetricSecurityKey(key),
                    ValidateIssuer = false,
                    ValidateAudience = false,
                    ValidateLifetime = true,
                    ClockSkew = TimeSpan.Zero
                };

                var principal = tokenHandler.ValidateToken(jwt, validationParameters, out _);
                var userIdClaim = principal.FindFirst(ClaimTypes.NameIdentifier) ??
                                 principal.FindFirst(JwtRegisteredClaimNames.Sub);

                return userIdClaim?.Value;
            }
            catch
            {
                return null;
            }
        }

        public Task<string> EncryptTokenAsync(string token)
        {
            return Task.FromResult(EncryptToken(token));
        }

        public Task<string> DecryptTokenAsync(string encryptedToken)
        {
            return Task.FromResult(DecryptToken(encryptedToken));
        }
    }
}
