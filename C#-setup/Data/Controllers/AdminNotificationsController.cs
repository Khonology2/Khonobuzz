using Microsoft.AspNetCore.Mvc;
using MyApi.Services;

namespace MyApi.Controllers;

[ApiController]
[Route("api/admin/notifications")]
public class AdminNotificationsController : ControllerBase
{
    private readonly IKhonoRelationalService _relational;

    public AdminNotificationsController(IKhonoRelationalService relational) => _relational = relational;

    [HttpPost]
    public async Task<IActionResult> CreateNotification([FromBody] AdminNotificationCreateRequest payload)
    {
        var actorEmail = (payload.ActorEmail ?? "").Trim().ToLowerInvariant();
        var title = (payload.Title ?? "").Trim();
        var message = (payload.Message ?? "").Trim();
        var area = (payload.Area ?? "general").Trim();
        var targetRoles = payload.TargetRoles ?? new List<string> { "admin", "staff" };
        var normalizedRoles = targetRoles
            .Select(r => r.Trim().ToLowerInvariant())
            .Where(r => r.Length > 0)
            .Distinct()
            .OrderBy(r => r)
            .ToList();

        if (string.IsNullOrEmpty(actorEmail) || string.IsNullOrEmpty(title) || string.IsNullOrEmpty(message))
            return BadRequest(new { detail = "actorEmail, title and message are required" });
        if (normalizedRoles.Count == 0)
            normalizedRoles = new List<string> { "admin", "staff" };

        var details = payload.Details ?? new Dictionary<string, object>();
        if (!details.ContainsKey("targetCount"))
            details["targetCount"] = normalizedRoles.Count;

        var (id, createdAtIso) = await _relational.CreateAdminNotificationAsync(
            actorEmail,
            title,
            message,
            area,
            normalizedRoles,
            details,
            payload.RequiresAck,
            payload.EffectiveDateIso ?? "");

        return StatusCode(201, new
        {
            message = "Notification created",
            id,
            createdAtIso
        });
    }

    [HttpGet]
    public async Task<IActionResult> ListNotifications(
        [FromQuery] string role,
        [FromQuery] string? userEmail = null,
        [FromQuery] int limit = 30)
    {
        var normalizedRole = (role ?? "").Trim().ToLowerInvariant();
        var normalizedEmail = (userEmail ?? "").Trim().ToLowerInvariant();
        if (string.IsNullOrEmpty(normalizedRole))
            return BadRequest(new { detail = "role is required" });

        if (normalizedRole == "staff")
            limit = Math.Min(limit, 30);
        limit = Math.Clamp(limit, 1, 200);

        var alerts = await _relational.ListAdminNotificationsAsync(normalizedRole, normalizedEmail, limit);
        return Ok(new { alerts });
    }

    [HttpPost("clear")]
    public async Task<IActionResult> ClearNotifications([FromBody] AdminNotificationClearRequest payload)
    {
        var normalizedRole = (payload.Role ?? "").Trim().ToLowerInvariant();
        var normalizedEmail = (payload.UserEmail ?? "").Trim().ToLowerInvariant();
        if (string.IsNullOrEmpty(normalizedRole) || string.IsNullOrEmpty(normalizedEmail))
            return BadRequest(new { detail = "role and userEmail are required" });

        await _relational.ClearAdminNotificationsAsync(normalizedRole, normalizedEmail);
        return Ok(new { message = "Alerts cleared" });
    }

    [HttpPost("dismiss")]
    public async Task<IActionResult> DismissNotification([FromBody] AdminNotificationDismissRequest payload)
    {
        var normalizedEmail = (payload.UserEmail ?? "").Trim().ToLowerInvariant();
        var alertId = (payload.AlertId ?? "").Trim();
        if (string.IsNullOrEmpty(normalizedEmail) || string.IsNullOrEmpty(alertId))
            return BadRequest(new { detail = "userEmail and alertId are required" });

        await _relational.DismissAdminNotificationAsync(normalizedEmail, alertId);
        return Ok(new { message = "Alert dismissed" });
    }

    [HttpPost("ack")]
    public async Task<IActionResult> AcknowledgeNotification([FromBody] AdminNotificationAckRequest payload)
    {
        var normalizedEmail = (payload.UserEmail ?? "").Trim().ToLowerInvariant();
        var alertId = (payload.AlertId ?? "").Trim();
        if (string.IsNullOrEmpty(normalizedEmail) || string.IsNullOrEmpty(alertId))
            return BadRequest(new { detail = "userEmail and alertId are required" });

        var found = await _relational.AcknowledgeAdminNotificationAsync(normalizedEmail, alertId);
        if (!found)
            return NotFound(new { detail = "Notification not found" });
        return Ok(new { message = "Alert acknowledged" });
    }
}

public class AdminNotificationCreateRequest
{
    public string? ActorEmail { get; set; }
    public string? Title { get; set; }
    public string? Message { get; set; }
    public string? Area { get; set; }
    public Dictionary<string, object>? Details { get; set; }
    public List<string>? TargetRoles { get; set; }
    public bool RequiresAck { get; set; }
    public string? EffectiveDateIso { get; set; }
}

public class AdminNotificationClearRequest
{
    public string? Role { get; set; }
    public string? UserEmail { get; set; }
}

public class AdminNotificationDismissRequest
{
    public string? Role { get; set; }
    public string? UserEmail { get; set; }
    public string? AlertId { get; set; }
}

public class AdminNotificationAckRequest
{
    public string? UserEmail { get; set; }
    public string? AlertId { get; set; }
}
