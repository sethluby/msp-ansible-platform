# Gitea Wiki Setup Guide

**Author**: thndrchckn  
**Purpose**: Instructions for setting up and managing the Gitea wiki for CMMC documentation

## Gitea Wiki Management

Gitea wikis are Git repositories that can be managed through both the web interface and Git commands. This provides flexibility for documentation management.

## Setup Methods

### Method 1: Web Interface (Initial Setup)
1. Navigate to your repository at `http://git.lan.sethluby.com:3000/thndrchckn/cmmc-ansible`
2. Click the "Wiki" tab
3. Click "Create the first page" if wiki doesn't exist
4. Create a page titled "Home" with initial content
5. The wiki repository is now created and accessible via Git

### Method 2: Git Clone (Preferred for Bulk Management)
```bash
# Clone the wiki repository
git clone ssh://git@git.lan.sethluby.com:222/thndrchckn/cmmc-ansible.wiki.git

# Navigate to wiki directory
cd cmmc-ansible.wiki

# Add your markdown files
cp ../cmmc-ansible/wiki/*.md .

# Commit and push
git add .
git commit -m "Initial wiki documentation"
git push origin master
```

## Wiki Structure

The wiki files in this repository (`wiki/` directory) are designed to be pushed to the Gitea wiki repository:

```
wiki/
├── Home.md                    # Main wiki homepage
├── Getting-Started.md         # Quick start guide
├── Architecture-Overview.md   # System architecture
├── CMMC-Controls/            # Control-specific documentation
├── Examples/                 # Code examples and use cases
├── Troubleshooting/          # Problem resolution guides
└── API-Documentation/        # Integration documentation
```

## Pushing Wiki Content

### Initial Wiki Setup
```bash
# From the main project directory
cd /home/thndrchckn/Documents/Projects/cmmc

# Clone the wiki repository (created via web interface first)
git clone ssh://git@git.lan.sethluby.com:222/thndrchckn/cmmc-ansible.wiki.git wiki-repo

# Copy wiki content
cp wiki/*.md wiki-repo/

# Push to wiki
cd wiki-repo
git add .
git commit -m "Initial comprehensive wiki documentation

- Added main homepage with navigation structure
- Created detailed getting started guide
- Established documentation framework for all CMMC components
- Set up cross-reference system with tags"
git push origin master
```

### Updating Wiki Content
```bash
# Update wiki content in main repository
vim wiki/Getting-Started.md

# Sync changes to wiki repository
cp wiki/*.md wiki-repo/
cd wiki-repo
git add .
git commit -m "Updated getting started guide with latest procedures"
git push origin master
```

## Wiki Features

### Gitea Wiki Capabilities
- **Markdown support** with GitHub-flavored syntax
- **File uploads** for images and documents
- **Cross-page linking** with `[[Page-Name]]` syntax
- **Table of contents** auto-generation
- **Search functionality** across all wiki pages
- **Version history** with Git-based tracking
- **Collaborative editing** with Git workflow

### Planned Wiki Sections

#### Technical Documentation
- Detailed implementation guides for each Ansible role
- Step-by-step CMMC control implementation
- Troubleshooting procedures with common solutions
- Architecture diagrams and data flow documentation

#### Business Documentation
- Pricing models and service tier explanations
- Client onboarding procedures and checklists
- SLA templates and service agreements
- Market positioning and competitive analysis

#### Operational Procedures
- Day-to-day management procedures
- Incident response and escalation procedures
- Backup and recovery procedures
- Change management and deployment procedures

#### Examples and Templates
- Configuration examples for different scenarios
- Client-specific deployment templates
- Integration examples with third-party tools
- Custom automation development guides

## Maintenance Workflow

### Regular Updates
1. Update documentation in main repository `wiki/` directory
2. Test documentation accuracy against current implementation
3. Sync changes to Gitea wiki repository
4. Verify links and navigation work correctly
5. Update index pages and cross-references

### Collaborative Editing
1. Multiple contributors can edit via Git workflow
2. Use branching for major documentation updates
3. Review process through pull requests (if configured)
4. Automated deployment hooks (can be configured)

## Wiki Access

- **Public Access**: Configure repository wiki visibility in Gitea settings
- **Team Access**: Manage via Gitea organization and team permissions
- **Client Access**: Separate client-specific documentation sections
- **Search**: Full-text search across all wiki content

## Integration Points

### Repository Integration
- Link to source code from documentation
- Reference specific file paths and line numbers
- Embed code examples with syntax highlighting
- Cross-reference between README files and wiki

### Automation Integration
- Document Ansible playbook execution examples
- Link to validation scripts and their output
- Reference configuration templates and their usage
- Provide troubleshooting for automated deployments

### Compliance Integration
- Map documentation to specific CMMC controls
- Provide evidence links for compliance audits
- Reference validation procedures and results
- Maintain audit trail of documentation changes

This wiki setup provides comprehensive documentation that supports both technical implementation and business operations for the MSP CMMC compliance platform.