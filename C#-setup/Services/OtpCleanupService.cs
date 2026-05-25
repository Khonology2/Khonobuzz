namespace MyApi.Services
{
    public class OtpCleanupService : BackgroundService
    {
        private readonly ILogger<OtpCleanupService> _logger;

        public OtpCleanupService(ILogger<OtpCleanupService> logger)
        {
            _logger = logger;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation("OTP Cleanup Service started (in-memory OTP - no DB cleanup needed)");
            while (!stoppingToken.IsCancellationRequested)
                await Task.Delay(TimeSpan.FromHours(1), stoppingToken);
        }
    }
}
