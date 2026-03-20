using MailKit.Net.Smtp;
using MimeKit;
using MyApi.Models;

namespace MyApi.Services
{
    public class EmailService : IEmailService
    {
        private readonly IConfiguration _configuration;

        public EmailService(IConfiguration configuration)
        {
            _configuration = configuration;
        }

        public async Task SendOtpEmailAsync(string email, string otp)
        {
            var message = new MimeMessage();
            message.From.Add(new MailboxAddress(
                _configuration["Smtp:FromName"],
                _configuration["Smtp:FromEmail"]));
            message.To.Add(new MailboxAddress("", email));
            message.Subject = "Your OTP Code";

            var bodyBuilder = new BodyBuilder();
            bodyBuilder.HtmlBody = $@"
                <div style='font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;'>
                    <h2>OTP Verification</h2>
                    <p>Your one-time password is:</p>
                    <div style='font-size: 24px; font-weight: bold; color: #007bff; padding: 10px; border: 1px solid #007bff; display: inline-block; margin: 10px 0;'>
                        {otp}
                    </div>
                    <p>This code will expire in {_configuration["Otp:ExpirationMinutes"]} minutes.</p>
                    <p>If you didn't request this code, please ignore this email.</p>
                </div>";

            message.Body = bodyBuilder.ToMessageBody();

            await SendEmailAsync(message);
        }

        public async Task SendWelcomeEmailAsync(string email, string name)
        {
            var message = new MimeMessage();
            message.From.Add(new MailboxAddress(
                _configuration["Smtp:FromName"],
                _configuration["Smtp:FromEmail"]));
            message.To.Add(new MailboxAddress("", email));
            message.Subject = "Welcome to KhonoBuzz";

            var bodyBuilder = new BodyBuilder();
            bodyBuilder.HtmlBody = $@"
                <div style='font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;'>
                    <h2>Welcome to KhonoBuzz, {name}!</h2>
                    <p>Your account has been successfully activated.</p>
                    <p>You can now access all features of the KhonoBuzz platform.</p>
                    <p>If you have any questions, please don't hesitate to contact our support team.</p>
                </div>";

            message.Body = bodyBuilder.ToMessageBody();

            await SendEmailAsync(message);
        }

        private async Task SendEmailAsync(MimeMessage message)
        {
            using var client = new SmtpClient();

            var smtpPort = _configuration["Smtp:Port"] ?? throw new InvalidOperationException("SMTP Port not configured");

            await client.ConnectAsync(
                _configuration["Smtp:Host"],
                int.Parse(smtpPort),
                bool.Parse(_configuration["Smtp:UseSsl"] ?? "true"));

            await client.AuthenticateAsync(
                _configuration["Smtp:Username"],
                _configuration["Smtp:Password"]);

            await client.SendAsync(message);
            await client.DisconnectAsync(true);
        }
    }
}
