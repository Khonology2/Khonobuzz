# GitHub Version Control Workflows

This directory contains GitHub Actions workflows for automatic version control management in the Personal Development Hub Android application.

## 🚀 Workflows Overview

### 1. Auto Version Update (`auto-version-update.yml`)
**Triggers:**
- Push to `main`, `develop`, `feature/*`, `hotfix/*` branches
- Pull requests to `main` and `develop`
- Manual workflow dispatch

**Features:**
- Automatically updates version control widget with current date and commit information
- Generates `daily-commits.json` with recent commit data
- Calculates version components (year, month, week code, day code, commit count, environment)
- Commits and pushes changes back to repository

**Version Format:** `Ver. YEAR.MONTH.WEEK_CODE+DAY_CODECOMMIT_COUNT.ENVIRONMENT`

### 2. Version API (`version-api.yml`)
**Triggers:**
- Push to `main` and `develop` branches
- Manual workflow dispatch

**Features:**
- Extracts current version information from widget
- Creates API response JSON with version details
- Uploads version artifact for consumption
- Displays version summary in workflow run

### 3. Version Release (`version-release.yml`)
**Triggers:**
- Push with version tags (`v*`)
- Manual workflow dispatch with release type selection

**Features:**
- Creates GitHub releases with version information
- Generates comprehensive release notes
- Uploads `daily-commits.json` as release asset
- Supports prerelease detection based on environment

### 4. Version Monitor (`version-monitor.yml`)
**Triggers:**
- Scheduled run every hour
- Manual workflow dispatch

**Features:**
- Monitors version consistency across widget, JSON, and actual git commits
- Creates detailed version reports
- Automatically creates GitHub issues if inconsistencies detected
- Uploads monitor reports as artifacts

## 📋 Version Components

### Year (YYYY)
Current calendar year extracted from system date.

### Month (MM)
Current month in two-digit format (01-12).

### Week Code (A-E)
Week of month converted to letter:
- A = Week 1
- B = Week 2
- C = Week 3
- D = Week 4
- E = Week 5

### Day Code (A-G)
Day of week converted to letter:
- A = Monday
- B = Tuesday
- C = Wednesday
- D = Thursday
- E = Friday
- F = Saturday
- G = Sunday

### Commit Count
Total number of commits in the repository.

### Environment
Based on branch:
- `main` → PROD
- `develop` → DEV
- Other branches → SIT

## 🔧 Configuration

### Required Files
- `lib/widgets/version_control.dart` - Version widget with static constants
- `assets/data/daily-commits.json` - Commit data JSON file

### Permissions
Workflows require the following GitHub token permissions:
- `contents: write` - For committing version updates
- `pull-requests: write` - For creating issues (monitor workflow)

### Secrets
No additional secrets required beyond the default `GITHUB_TOKEN`.

## 🚀 Usage

### Automatic Updates
Version updates happen automatically on every push to supported branches. No manual intervention required.

### Manual Triggers
All workflows support manual triggering via GitHub Actions UI:
1. Go to Actions tab in your repository
2. Select the desired workflow
3. Click "Run workflow"
4. Configure inputs if available
5. Click "Run workflow"

### Force Updates
Use the "Force version update" option in the auto-version-update workflow to bypass change detection and force an update.

### Creating Releases
1. Tag a commit with `v*` (e.g., `v1.0.0`)
2. Push the tag
3. The version-release workflow will automatically create a release
4. Or manually trigger the workflow and select release type

## 📊 Monitoring

### Version Consistency
The monitor workflow checks for consistency between:
- Version widget constants
- JSON file version data
- Actual git commit count

### Reports
Monitor reports include:
- Version status and consistency
- Commit count comparison
- Latest commit information
- Recommended actions

### Issues
Inconsistencies automatically create GitHub issues with:
- Version monitor report
- Recommended fixes
- Automated labels

## 🔍 Troubleshooting

### Common Issues
1. **Workflow fails on permissions** - Ensure repository settings allow Actions to write to repository
2. **Version not updating** - Check if changes were committed and pushed
3. **Inconsistent versions** - Run monitor workflow to identify discrepancies
4. **Release creation fails** - Verify tag format and branch permissions

### Debugging
1. Check workflow run logs for detailed error messages
2. Review version monitor reports for inconsistencies
3. Verify file permissions and repository settings
4. Check git history for recent changes

## 📝 Examples

### Example Version String
`Ver. 2026.02.BA123.SIT`

Breakdown:
- Year: 2026
- Month: 02 (February)
- Week Code: B (Week 2 of month)
- Day Code: A (Monday)
- Commit Count: 123
- Environment: SIT

### Example Workflow Trigger
```bash
# Push to feature branch
git push origin feature/new-feature

# This triggers auto-version-update workflow
# Version gets updated automatically
```

### Example Manual Release
1. Go to Actions → Version Release
2. Click "Run workflow"
3. Select release type: "patch"
4. Click "Run workflow"
5. Release created with version information

## 🔄 Integration

### Flutter App Integration
The version widget automatically displays the current version:
```dart
// In landing_screen.dart
Positioned(
  bottom: 20,
  left: 0,
  right: 0,
  child: Align(
    alignment: Alignment.center,
    child: const VersionControlOverlay(),
  ),
),
```

### API Integration
Version information available through workflow artifacts:
- Download `version-info.json` from workflow runs
- Parse version components programmatically
- Use for external integrations and monitoring

## 📚 Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Workflow Syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [GitHub CLI](https://cli.github.com/manual/)
- [Git Versioning Best Practices](https://semver.org/)
