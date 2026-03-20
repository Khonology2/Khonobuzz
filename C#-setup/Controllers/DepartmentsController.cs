using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using MyApi.Services;
using MyApi.Models;
using MyApi.Data;
using Microsoft.EntityFrameworkCore;

namespace MyApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class DepartmentsController : ControllerBase
    {
        private readonly ApplicationDbContext _context;

        public DepartmentsController(ApplicationDbContext context)
        {
            _context = context;
        }

        [HttpGet]
        public async Task<IActionResult> GetDepartments()
        {
            var departments = await _context.Departments
                .Select(d => new
                {
                    d.Id,
                    d.Name,
                    d.Description,
                    d.CreatedAt
                })
                .ToListAsync();

            return Ok(new { Departments = departments });
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetDepartment(string id)
        {
            var department = await _context.Departments
                .FirstOrDefaultAsync(d => d.Id == id);

            if (department == null)
            {
                return NotFound(new { Message = "Department not found." });
            }

            var response = new
            {
                department.Id,
                department.Name,
                department.Description,
                department.CreatedAt
            };

            return Ok(response);
        }

        [HttpPost]
        [Authorize(Roles = "admin")]
        public async Task<IActionResult> CreateDepartment([FromBody] Department department)
        {
            department.Id = Guid.NewGuid().ToString();
            department.CreatedAt = DateTime.UtcNow;
            department.UpdatedAt = DateTime.UtcNow;

            _context.Departments.Add(department);
            await _context.SaveChangesAsync();

            var response = new
            {
                department.Id,
                department.Name,
                department.Description,
                Message = "Department created successfully."
            };

            return CreatedAtAction(nameof(GetDepartment), new { id = department.Id }, response);
        }

        [HttpPut("{id}")]
        [Authorize(Roles = "admin")]
        public async Task<IActionResult> UpdateDepartment(string id, [FromBody] Department updateDepartment)
        {
            var department = await _context.Departments.FirstOrDefaultAsync(d => d.Id == id);
            if (department == null)
            {
                return NotFound(new { Message = "Department not found." });
            }

            department.Name = updateDepartment.Name ?? department.Name;
            department.Description = updateDepartment.Description ?? department.Description;
            department.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();

            var response = new
            {
                department.Id,
                department.Name,
                department.Description,
                Message = "Department updated successfully."
            };

            return Ok(response);
        }

        [HttpDelete("{id}")]
        [Authorize(Roles = "admin")]
        public async Task<IActionResult> DeleteDepartment(string id)
        {
            var department = await _context.Departments.FirstOrDefaultAsync(d => d.Id == id);
            if (department == null)
            {
                return NotFound(new { Message = "Department not found." });
            }

            _context.Departments.Remove(department);
            await _context.SaveChangesAsync();

            return Ok(new { Message = "Department deleted successfully." });
        }
    }
}
