#!/bin/bash

# Script to push changes to GitHub
# This script will help you push your local changes to your GitHub repository

cd "$(dirname "$0")"

echo "📦 Checking repository status..."
git status

echo ""
echo "🔄 Pushing to GitHub..."
echo "You may be prompted for your GitHub credentials."
echo "Username: debruehe"
echo "Password: Use a Personal Access Token (not your GitHub password)"
echo ""

# Try to push with SSL verification (normal case)
if git push -u origin main; then
    echo "✅ Successfully pushed to GitHub!"
    echo "Repository: https://github.com/debruehe/Spotipi-eink-custom-v3.1"
else
    echo ""
    echo "⚠️  Push failed. Trying with SSL verification disabled..."
    GIT_SSL_NO_VERIFY=1 git push -u origin main
fi

