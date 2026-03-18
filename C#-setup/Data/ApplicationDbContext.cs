using Microsoft.EntityFrameworkCore;
using MyApi.Models;

namespace MyApi.Data
{
    public class ApplicationDbContext : DbContext
    {
        public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
            : base(options)
        {
        }

        public DbSet<User> Users { get; set; }
        public DbSet<Onboarding> Onboardings { get; set; }
        public DbSet<Department> Departments { get; set; }
        public DbSet<Role> Roles { get; set; }
        public DbSet<OTPCode> OTPCodes { get; set; }
        public DbSet<RateLimit> RateLimits { get; set; }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            // Configure relationships and constraints here if needed
            modelBuilder.Entity<Onboarding>()
                .HasOne(o => o.User)
                .WithOne(u => u.Onboarding)
                .HasForeignKey<Onboarding>(o => o.UserId);

            // Add any additional configurations
        }
    }
}
