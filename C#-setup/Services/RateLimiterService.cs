using System.Collections.Concurrent;
using MyApi.Models;

namespace MyApi.Services
{
    public class RateLimiterService : IRateLimiterService
    {
        // In-memory storage for rate limits
        private static readonly ConcurrentDictionary<string, RateLimit> _rateLimits = new();

        private readonly IConfiguration _configuration;

        public RateLimiterService(IConfiguration configuration)
        {
            _configuration = configuration;
        }

        public async Task<bool> IsRateLimitedAsync(string identifier)
        {
            // Clean up expired rate limit records
            await CleanupExpiredRecordsAsync();

            var now = DateTime.UtcNow;
            var windowMinutes = _configuration.GetValue<int>("RateLimit:WindowMinutes", 15);
            var windowStart = now.AddMinutes(-windowMinutes);

            if (!_rateLimits.TryGetValue(identifier, out var rateLimit))
            {
                return false; // No record means not rate limited
            }

            // Check if we're in a new window
            if (rateLimit.WindowStart < windowStart)
            {
                // Reset for new window
                rateLimit.RequestCount = 0;
                rateLimit.WindowStart = now;
                rateLimit.WindowEnd = now.AddMinutes(windowMinutes);
                return false;
            }

            var maxRequests = _configuration.GetValue<int>("RateLimit:Requests", 100);
            return rateLimit.RequestCount >= maxRequests;
        }

        public async Task RecordRequestAsync(string identifier)
        {
            var now = DateTime.UtcNow;
            var windowMinutes = _configuration.GetValue<int>("RateLimit:WindowMinutes", 15);
            var windowEnd = now.AddMinutes(windowMinutes);

            if (!_rateLimits.TryGetValue(identifier, out var rateLimit))
            {
                // Create new record
                rateLimit = new RateLimit
                {
                    Id = Guid.NewGuid().ToString(),
                    Identifier = identifier,
                    RequestCount = 1,
                    WindowStart = now,
                    WindowEnd = windowEnd
                };
                _rateLimits[identifier] = rateLimit;
            }
            else
            {
                // Check if we need to reset the window
                var windowStart = now.AddMinutes(-windowMinutes);
                if (rateLimit.WindowStart < windowStart)
                {
                    rateLimit.RequestCount = 1;
                    rateLimit.WindowStart = now;
                    rateLimit.WindowEnd = windowEnd;
                }
                else
                {
                    rateLimit.RequestCount++;
                }
            }
        }

        private async Task CleanupExpiredRecordsAsync()
        {
            var now = DateTime.UtcNow;
            var expiredKeys = _rateLimits.Where(kvp => kvp.Value.WindowEnd < now)
                .Select(kvp => kvp.Key)
                .ToList();

            foreach (var key in expiredKeys)
            {
                _rateLimits.TryRemove(key, out _);
            }
        }
    }
}
