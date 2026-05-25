using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace MyApi.Data.Entities;

[Table("kb_user_profile")]
public class KbUserProfile
{
    [Key]
    [Column("user_id")]
    public string UserId { get; set; } = "";

    [Column("first_name")]
    public string FirstName { get; set; } = "";

    [Column("last_name")]
    public string LastName { get; set; } = "";

    [Column("surname")]
    public string Surname { get; set; } = "";

    [Column("preferred_name")]
    public string PreferredName { get; set; } = "";

    [Column("full_name")]
    public string FullName { get; set; } = "";

    [Column("phone_number")]
    public string PhoneNumber { get; set; } = "";

    [Column("department")]
    public string Department { get; set; } = "";

    [Column("designation")]
    public string Designation { get; set; } = "";

    [Column("entity")]
    public string Entity { get; set; } = "";

    [Column("manager")]
    public string Manager { get; set; } = "";

    [Column("managed_by")]
    public string ManagedBy { get; set; } = "";

    [Column("module_access")]
    public string ModuleAccess { get; set; } = "";

    [Column("module_role")]
    public string ModuleRole { get; set; } = "";

    [Column("module_access_role")]
    public string ModuleAccessRole { get; set; } = "";

    [Column("profile_image_url")]
    public string ProfileImageUrl { get; set; } = "";

    [Column("profile_image_public_id")]
    public string ProfileImagePublicId { get; set; } = "";

    [Column("theme_preference")]
    public string ThemePreference { get; set; } = "dark";

    [Column("token")]
    public string? Token { get; set; }

    [Column("token_updated_at")]
    public DateTime? TokenUpdatedAt { get; set; }

    [Column("onboarding_role")]
    public string OnboardingRole { get; set; } = "";

    [Column("onboarding_status")]
    public string OnboardingStatus { get; set; } = "";

    [Column("admin_json", TypeName = "jsonb")]
    public string? AdminJson { get; set; }

    [Column("last_sign_in_at")]
    public DateTime? LastSignInAt { get; set; }

    [Column("login_count")]
    public int LoginCount { get; set; }

    [Column("created_at")]
    public DateTime? CreatedAt { get; set; }

    [Column("updated_at")]
    public DateTime? UpdatedAt { get; set; }

    [Column("extra", TypeName = "jsonb")]
    public string? Extra { get; set; }

    public KbAppUser? User { get; set; }
}
