using Microsoft.EntityFrameworkCore;
using MyApi.Data.Entities;

namespace MyApi.Data;

public class KhonoDbContext : DbContext
{
    public KhonoDbContext(DbContextOptions<KhonoDbContext> options) : base(options) { }

    public DbSet<KbAppUser> AppUsers => Set<KbAppUser>();
    public DbSet<KbUserEmail> UserEmails => Set<KbUserEmail>();
    public DbSet<KbUserProfile> UserProfiles => Set<KbUserProfile>();
    public DbSet<KbRoleDefinition> RoleDefinitions => Set<KbRoleDefinition>();
    public DbSet<KbDepartment> Departments => Set<KbDepartment>();
    public DbSet<KbDesignation> Designations => Set<KbDesignation>();
    public DbSet<KbEntity> Entities => Set<KbEntity>();
    public DbSet<KbAdminNotification> AdminNotifications => Set<KbAdminNotification>();
    public DbSet<KbAdminNotificationState> AdminNotificationStates => Set<KbAdminNotificationState>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<KbAppUser>()
            .HasIndex(u => u.Email)
            .IsUnique();

        modelBuilder.Entity<KbAppUser>()
            .HasOne(u => u.Profile)
            .WithOne(p => p.User)
            .HasForeignKey<KbUserProfile>(p => p.UserId)
            .OnDelete(DeleteBehavior.Cascade);
    }
}
