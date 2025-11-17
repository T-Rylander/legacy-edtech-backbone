# GitHub Repository Setup Instructions

## Current Status

✅ Repository scaffolded locally at: `F:\Sources\Repos\legacy-edtech-backbone`

✅ All files committed to local git

## Next Steps

### 1. Create GitHub Repository

1. Go to https://github.com/new
2. Repository name: `legacy-edtech-backbone`
3. Description: "Zero-Touch EdTech Stack on Repurposed Gear"
4. Visibility: **Public** (for open-source sharing)
5. **Do NOT** initialize with README, .gitignore, or license (we already have these)
6. Click "Create repository"

### 2. Push Local Repository

```powershell
# Add GitHub remote
git remote add origin https://github.com/T-Rylander/legacy-edtech-backbone.git

# Rename branch to main (if needed)
git branch -M main

# Push to GitHub
git push -u origin main
```

### 3. Configure GitHub Pages

1. Go to repository **Settings** → **Pages**
2. Source: **Deploy from a branch**
3. Branch: `gh-pages` (will be created by MkDocs)
4. Folder: `/ (root)`
5. Click **Save**

### 4. Add GitHub Pages Deployment Workflow

Create `.github/workflows/deploy-docs.yml`:

```yaml
name: Deploy Documentation

on:
  push:
    branches: [ main ]
    paths:
      - 'docs/**'
      - 'mkdocs.yml'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Setup Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'
      
      - name: Install MkDocs
        run: |
          pip install mkdocs-material pymdown-extensions mkdocs-git-revision-date-localized-plugin
      
      - name: Deploy to GitHub Pages
        run: mkdocs gh-deploy --force
```

Then commit and push:

```powershell
git add .github/workflows/deploy-docs.yml
git commit -m "ci: Add GitHub Pages deployment workflow"
git push
```

### 5. Enable GitHub Actions

1. Go to repository **Settings** → **Actions** → **General**
2. Workflow permissions: **Read and write permissions**
3. Allow GitHub Actions to create and approve pull requests: ✅
4. Click **Save**

### 6. Verify Setup

After pushing:

1. **Actions tab**: Check that workflows run successfully
2. **GitHub Pages**: Documentation will be live at `https://t-rylander.github.io/legacy-edtech-backbone/`
3. **About section**: Add website link and topics (edtech, samba, pxe, homelab, infrastructure)

## Repository Topics

Add these topics to help discovery:
- `edtech`
- `samba`
- `active-directory`
- `pxe-boot`
- `raspberry-pi`
- `unifi`
- `infrastructure`
- `automation`
- `mkdocs`
- `homelab`

## File Structure Summary

```
legacy-edtech-backbone/
├── .github/
│   ├── copilot-instructions.md
│   └── workflows/
│       └── validate-scripts.yml
├── docs/                      # 10 documentation pages
├── scripts/                   # 6 bash automation scripts
├── .env.example
├── .gitignore
├── CONTRIBUTING.md
├── LICENSE (MIT)
├── mkdocs.yml
└── README.md
```

## Quick Commands Reference

```powershell
# Check repository status
git status
git log --oneline -5

# View remote
git remote -v

# Push changes
git add .
git commit -m "type: description"
git push

# Build docs locally
mkdocs serve
# Open http://localhost:8000

# Validate scripts
shellcheck scripts/*.sh
```

---

**Ready to push!** Follow steps 1-2 above to create the GitHub repo and push your local commits.
