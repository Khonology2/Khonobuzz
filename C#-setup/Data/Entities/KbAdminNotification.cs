using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace MyApi.Data.Entities;

[Table("kb_admin_notification")]
public class KbAdminNotification
{
    [Key]
    [Column("id")]
    public string Id { get; set; } = "";

    [Column("actor_email")]
    public string ActorEmail { get; set; } = "";

    [Column("title")]
    public string Title { get; set; } = "";

    [Column("message")]
    public string Message { get; set; } = "";

    [Column("area")]
    public string Area { get; set; } = "general";

    [Column("details", TypeName = "jsonb")]
    public string? Details { get; set; }

    [Column("target_roles", TypeName = "jsonb")]
    public string? TargetRoles { get; set; }

    [Column("requires_ack")]
    public bool RequiresAck { get; set; }

    [Column("effective_date_iso")]
    public string EffectiveDateIso { get; set; } = "";

    [Column("acknowledged_by_emails", TypeName = "jsonb")]
    public string? AcknowledgedByEmails { get; set; }

    [Column("created_at_iso")]
    public string CreatedAtIso { get; set; } = "";

    [Column("created_at")]
    public DateTime? CreatedAt { get; set; }

    [Column("raw", TypeName = "jsonb")]
    public string? Raw { get; set; }
}
