#!/bin/bash

# ═══════════════════════════════════════════════════════════════════════════════
#  OllamaBot Sync Script
#  Stage, commit, and push to ai_interns branch
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Config
REPO="cadenroberts/ollamabot"
BRANCH="ai_interns"

echo -e "${CYAN}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                    🤖 OllamaBot Sync Script                   ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check if we're in a git repo
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    echo -e "${RED}Error: Not a git repository${NC}"
    exit 1
fi

# Check if remote exists
if ! git remote get-url origin > /dev/null 2>&1; then
    echo -e "${YELLOW}Adding remote origin...${NC}"
    git remote add origin "git@github.com:${REPO}.git"
    echo -e "${GREEN}✓ Remote added: github.com/${REPO}${NC}"
fi

# Show status
echo -e "\n${BOLD}📊 Current Status:${NC}"
git status --short

# Check for changes
if git diff --quiet && git diff --cached --quiet; then
    echo -e "\n${YELLOW}No changes to commit.${NC}"
    
    # Check if we're ahead of remote
    if git rev-parse --verify origin/$BRANCH > /dev/null 2>&1; then
        AHEAD=$(git rev-list origin/$BRANCH..HEAD --count 2>/dev/null || echo "0")
        if [ "$AHEAD" -gt 0 ]; then
            echo -e "${CYAN}You have ${AHEAD} unpushed commit(s).${NC}"
            echo -e "${BOLD}🚀 Pushing to GitHub...${NC}"
            git push origin $BRANCH
            echo -e "${GREEN}✓ Pushed to github.com/${REPO}${NC}"
        fi
    fi
    exit 0
fi

# Get commit message
if [ -n "$1" ]; then
    MSG="$*"
    echo -e "\n${BOLD}💬 Commit Message:${NC} $MSG"
else
    MSG="Update $(date '+%Y-%m-%d %H:%M')"
    echo -e "\n${BOLD}💬 Using default message:${NC} $MSG"
fi

# Stage all changes
echo -e "\n${BOLD}📦 Staging changes...${NC}"
git add -A
git status --short

# Commit
echo -e "\n${BOLD}💾 Committing...${NC}"
git commit -m "$MSG"

# Push
echo -e "\n${BOLD}🚀 Pushing to GitHub...${NC}"

# Check if branch exists on remote
if ! git ls-remote --exit-code --heads origin $BRANCH > /dev/null 2>&1; then
    echo -e "${YELLOW}Branch '$BRANCH' doesn't exist on remote. Creating...${NC}"
    git push -u origin $BRANCH
else
    git push origin $BRANCH
fi

echo -e "\n${GREEN}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                    ✅ Sync Successful!                        ║"
echo "╠═══════════════════════════════════════════════════════════════╣"
echo "║  Repository: github.com/${REPO}                    ║"
echo "║  Branch:     ${BRANCH}                                      ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Show latest commit
echo -e "${BOLD}📝 Latest commit:${NC}"
git log -1 --pretty=format:"   %h - %s (%cr) <%an>" --abbrev-commit
echo -e "\n"
