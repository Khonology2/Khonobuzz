using Microsoft.EntityFrameworkCore;
using MyApi.Data;
using MyApi.Models;

namespace MyApi.Services
{
    public class RateLimitCleanupService : BackgroundService
    {
        private readonly IServiceProvider _serviceProvider;
        private readonly ILogger<RateLimitCleanupService> _logger;
        private readonly TimeSpan _cleanupInterval = TimeSpan.FromHours(1);

        public RateLimitCleanupService(IServiceProvider serviceProvider, ILogger<RateLimitCleanupService> logger)
        {
            _serviceProvider = serviceProvider;
            _logger = logger;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("Rate Limit Cleanup Service started");

            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    await CleanupExpiredRateLimitsAsync();
                    await Task.Delay(_cleanupInterval, stoppingToken);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error during rate limit cleanup");
                    await Task.Delay(TimeSpan.FromMinutes(5), stoppingToken);
                }
            }

            _logger.LogInformation("Rate Limit Cleanup Service stopped");
        }

        private async Task CleanupExpiredRateLimitsAsync()
        {
            using var scope = _serviceProvider.CreateScope();
            var context = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();

            var expiredRateLimits = await context.RateLimits
                .Where(r => r.WindowEnd < DateTime.UtcNow)
                .ToListAsync();

            if (expiredRateLimits.Any())
            {
                context.RateLimits.RemoveRange(expiredRateLimits);
                await context.SaveChangesAsync();
                _logger.LogInformation("Cleaned up {count} expired rate limit records", expiredRateLimits.Count);
            }
        }
    }
}
