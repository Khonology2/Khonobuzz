namespace MyApi.Services
{
    public class RateLimitCleanupService : BackgroundService
    {
        private readonly ILogger<RateLimitCleanupService> _logger;

        public RateLimitCleanupService(ILogger<RateLimitCleanupService> logger)
        {
            _logger = logger;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("Rate Limit Cleanup Service started (in-memory - no DB cleanup needed)");
            while (!stoppingToken.IsCancellationRequested)
                await Task.Delay(TimeSpan.FromHours(1), stoppingToken);
        }
    }
}
