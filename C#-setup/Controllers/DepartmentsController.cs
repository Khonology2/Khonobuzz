using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using MyApi.DTOs.Common;

namespace MyApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class DepartmentsController : ControllerBase
    {
        private readonly Services.IFirestoreService _firestore;

        public DepartmentsController(Services.IFirestoreService firestore)
        {
            _firestore = firestore;
        }

        [HttpGet]
        [AllowAnonymous]
        public async Task<IActionResult> GetDepartments()
        {
            var names = await _firestore.GetDepartmentNamesAsync();
            return Ok(new { departments = names });
        }

        [HttpPost]
        [Authorize(Roles = "admin")]
        public async Task<IActionResult> CreateDepartment([FromBody] NameBody? body)
        {
            var name = (body?.Name ?? "").Trim();
            if (string.IsNullOrEmpty(name))
                return BadRequest(new { detail = "name is required" });

            await _firestore.AddDepartmentIfNotExistsAsync(name);
            var names = await _firestore.GetDepartmentNamesAsync();
            return StatusCode(201, new { departments = names });
        }
    }
}
