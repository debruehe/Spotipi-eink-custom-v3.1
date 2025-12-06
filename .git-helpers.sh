#!/bin/bash

# Git helper functions for Spotipi-eink-custom-v3.1
# Source this file in your shell: source .git-helpers.sh

# Function to commit and push changes
spotipi-push() {
    local message="${1:-Update changes}"
    local repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    cd "$repo_dir"
    
    echo "📋 Checking status..."
    git status
    
    echo ""
    echo "➕ Staging all changes..."
    git add .
    
    echo ""
    echo "💾 Committing with message: '$message'"
    git commit -m "$message"
    
    echo ""
    echo "🚀 Pushing to GitHub..."
    if git push origin main; then
        echo "✅ Successfully pushed to GitHub!"
        echo "Repository: https://github.com/debruehe/Spotipi-eink-custom-v3.1"
    else
        echo "⚠️  Push failed. You may need to authenticate."
        echo "Try running: ./push-to-github.sh"
    fi
}

# Function to check status
spotipi-status() {
    local repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    cd "$repo_dir"
    git status
}

# Function to show recent commits
spotipi-log() {
    local repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    cd "$repo_dir"
    git log --oneline -10
}

echo "✅ Git helpers loaded! Available commands:"
echo "  spotipi-push 'commit message'  - Commit and push changes"
echo "  spotipi-status                - Check repository status"
echo "  spotipi-log                   - Show recent commits"

