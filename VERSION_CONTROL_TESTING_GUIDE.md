# Testing Guide: Flutter Version Control System

## 🚀 How to Test the Version Control Workflow

### Prerequisites
1. **Git Repository**: Ensure your code is pushed to a GitHub repository
2. **GitHub Actions**: Enabled in your repository settings
3. **Flutter App**: Built and running locally

### 🧪 Testing Steps

#### Step 1: Test Workflow Trigger (Manual)
1. **Go to GitHub Repository**
   - Navigate to your GitHub repository
   - Click on **Actions** tab

2. **Trigger Workflow Manually**
   - Select **"Generate Daily Commits"** workflow
   - Click **"Run workflow"**
   - Click **"Run workflow"** again

3. **Monitor Execution**
   - Watch the workflow run in real-time
   - Check logs for each step:
     - ✅ Checkout repository
     - ✅ Generate daily commits JSON
     - ✅ Verify JSON is valid
     - ✅ Display generated data
     - ✅ Commit and push changes

#### Step 2: Verify Generated Files
1. **Check Repository Files**
   ```bash
   # After workflow completes, check if files were updated
   git status
   git log --oneline -3
   ```

2. **Verify `assets/data/daily-commits.json`**
   - Should contain today's commits
   - Should have correct JSON structure
   - Should show commit count and version

3. **Check Commit History**
   - Look for commit message: "Update daily commits data [YYYY-MM-DD]"
   - Verify the JSON file was modified

#### Step 3: Test Automatic Triggers

1. **Push to Main Branch**
   ```bash
   # Make a small change
   echo "# Test commit" >> README.md
   git add README.md
   git commit -m "test: trigger workflow"
   git push origin main
   ```

2. **Monitor GitHub Actions**
   - Go to Actions tab
   - See workflow automatically trigger
   - Wait for completion

3. **Push to Feature Branch**
   ```bash
   git checkout -b feature/test-workflow
   echo "# Feature test" >> README.md
   git add README.md
   git commit -m "feat: test feature branch workflow"
   git push origin feature/test-workflow
   ```

4. **Verify Feature Branch Trigger**
   - Check Actions tab for workflow on feature branch

#### Step 4: Test Flutter App Integration

1. **Pull Latest Changes**
   ```bash
   git pull origin main
   ```

2. **Run Flutter App**
   ```bash
   flutter run
   ```

3. **Test Version Control Widget**
   - Navigate to landing screen
   - Look for version control at bottom center
   - **Hover over version text** (on web/desktop)
   - **Check tooltip** shows only feature commits in format: "GitHub username - feature commit message"

4. **Verify Data Loading**
   - Tooltip should show "Daily Commits" with only commits starting with "feature"
   - Version should update automatically every 5 seconds
   - Non-feature commits should not appear in tooltip

#### Step 5: Test Error Scenarios

1. **Test Offline Mode**
   - Disconnect internet
   - Restart Flutter app
   - Should show fallback data in tooltip

2. **Test Invalid JSON**
   - Temporarily corrupt `daily-commits.json`
   - Restart app
   - Should show fallback message

3. **Test App Lifecycle**
   - Background Flutter app
   - Resume app
   - Should refresh commit data automatically

### 🔍 Troubleshooting Common Issues

#### Workflow Not Triggering
```bash
# Check if workflow file exists
ls -la .github/workflows/generate-commits.yml

# Check workflow syntax
# Go to Actions tab → Select workflow → Click "..." → View workflow file
```

#### JSON Generation Issues
```bash
# Check if jq is available in workflow logs
# Look for "jq not available" error

# Verify git commands
git log --oneline -5
git log --since="2026-02-19T00:00:00Z" --pretty=format:'%an|%s|%aI' --no-merges
```

#### Flutter Asset Loading Issues
```bash
# Clean Flutter cache
flutter clean
flutter pub get

# Check asset path in pubspec.yaml
grep -A 5 "assets:" pubspec.yaml

# Verify file exists
ls -la assets/data/daily-commits.json
```

#### Version Widget Not Showing
```bash
# Check for import errors
flutter analyze

# Check console for errors
flutter run --debug
```

### 📊 Expected Results

#### ✅ Successful Test Indicators

1. **GitHub Actions**
   - Workflow completes without errors
   - Green checkmark on all steps
   - Commit created with message containing date

2. **Flutter App**
   - Version control widget visible at bottom center
   - Hover shows detailed commit information
   - Auto-refresh works (tooltip updates every 5 seconds)
   - No console errors related to commit loading

3. **Data Structure**
   ```json
   {
     "version": "2026.02.BA5.SIT",
     "generated_at": "2026-02-19T10:30:00Z",
     "commits": [
       {
         "author": "Developer Name",
         "message": "Feature: implement new feature",
         "timestamp": "2026-02-19T10:25:00Z"
       }
     ],
     "total_commits": 5,
     "date_range": "2026-02-19"
   }
   ```

### 🎯 Version Format Breakdown

**Example:** `Ver. 2026.02.BA5.SIT`

| Component | Description | Example |
|-----------|-------------|---------|
| `2026` | Year | Current year |
| `.02` | Month | Current month (02 = February) |
| `.B` | Week Code | B = Week 2 of month |
| `A` | Day Code | A = Monday |
| `5` | Commit Count | 5 commits today |
| `.SIT` | Environment | SIT (based on branch) |

### 🌟 Advanced Testing

#### Test Multiple Developers
1. **Create commits from different authors**
   ```bash
   # Set different git author
   git config user.name "John Doe"
   git config user.email "john@example.com"
   echo "# John commit" >> test.txt
   git add test.txt
   git commit -m "feat: john's feature"
   git push
   ```

2. **Check workflow includes all authors**
   - Tooltip should show commits from different developers

#### Test Environment Switching
1. **Push to different branches**
   ```bash
   # main branch → PROD environment
   git checkout main
   git push

   # develop branch → DEV environment
   git checkout develop
   git push
   ```

2. **Verify environment codes in version string**

#### Performance Testing
1. **Test with many commits**
   ```bash
   # Create multiple commits
   for i in {1..20}; do
     echo "Commit $i" >> bulk_test.txt
     git add bulk_test.txt
     git commit -m "test: bulk commit $i"
   done
   git push
   ```

2. **Monitor workflow execution time**
3. **Test Flutter app performance with large commit lists**

### 📋 Checklist for Complete Testing

- [ ] Manual workflow trigger works
- [ ] Automatic trigger on push works
- [ ] JSON file generates correctly
- [ ] Commit and push back to repo works
- [ ] Flutter app loads commit data
- [ ] Version widget displays correctly
- [ ] Hover tooltip shows commit details
- [ ] Auto-refresh works every 5 seconds
- [ ] Error handling works (offline mode)
- [ ] Multiple developers' commits show
- [ ] Different branch environments work
- [ ] Performance with many commits acceptable

### 🔄 Next Steps After Testing

1. **Monitor Real Usage**
   - Watch workflow runs in production
   - Check for any edge cases

2. **Continuous Improvement**
   - Add more author mapping if needed
   - Adjust refresh intervals if necessary
   - Add more error handling

3. **Documentation Updates**
   - Update team wiki with testing procedures
   - Document troubleshooting steps

This comprehensive testing approach ensures your version control system works reliably in all scenarios! 🎉
