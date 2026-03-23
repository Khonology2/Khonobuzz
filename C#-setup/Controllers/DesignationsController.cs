using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using MyApi.DTOs.Common;

namespace MyApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class DesignationsController : ControllerBase
    {
        private readonly Services.IFirestoreService _firestore;

        public DesignationsController(Services.IFirestoreService firestore)
        {
            _firestore = firestore;
        }

        [HttpGet]
        [AllowAnonymous]
        public async Task<IActionResult> GetDesignations()
        {
            var names = await _firestore.GetDesignationNamesAsync();
            return Ok(new { designations = names });
        }

        [HttpPost]
        [Authorize(Roles = "admin")]
        public async Task<IActionResult> CreateDesignation([FromBody] NameBody? body)
        {
            var name = (body?.Name ?? "").Trim();
            if (string.IsNullOrEmpty(name))
                return BadRequest(new { detail = "name is required" });

            await _firestore.AddDesignationIfNotExistsAsync(name);
            var names = await _firestore.GetDesignationNamesAsync();
            return StatusCode(201, new { designations = names });
        }
    }
}
