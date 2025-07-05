#!/bin/bash

echo "🔍 Verifying Playwriter v0.0.1 Release Package"
echo "=============================================="
echo

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if command succeeded
check_step() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ $1${NC}"
    else
        echo -e "${RED}❌ $1 FAILED${NC}"
        exit 1
    fi
}

# Function to check if file exists
check_file() {
    if [ -f "$1" ]; then
        echo -e "${GREEN}✅ $1 exists${NC}"
    else
        echo -e "${RED}❌ $1 missing${NC}"
        exit 1
    fi
}

echo "📋 Checking Essential Files..."
check_file "mix.exs"
check_file "README.md"
check_file "CHANGELOG.md"
check_file "LICENSE"
check_file "lib/playwriter.ex"
check_file "lib/playwriter/cli.ex"
check_file "lib/playwriter/fetcher.ex"
check_file "lib/playwriter/windows_browser_adapter.ex"
check_file "start_true_headed_server.sh"
check_file "kill_playwright.ps1"
check_file "list_chrome_profiles.ps1"
check_file "start_chromium.ps1"
echo

echo "🧹 Cleaning Build Environment..."
mix clean > /dev/null 2>&1
check_step "Clean completed"

echo "📦 Installing Dependencies..."
mix deps.get > /dev/null 2>&1
check_step "Dependencies installed"

echo "🔨 Compiling Project..."
mix compile > /dev/null 2>&1
check_step "Compilation successful"

echo "🧪 Running Tests..."
mix test > /dev/null 2>&1
check_step "Tests passed"

echo "📖 Generating Documentation..."
mix docs > /dev/null 2>&1
check_step "Documentation generated"

echo "📦 Building Hex Package..."
mix hex.build > /dev/null 2>&1
check_step "Hex package built"

echo "🔍 Verifying Package Contents..."
if [ -f "playwriter-0.0.1.tar" ]; then
    echo -e "${GREEN}✅ Package file created: playwriter-0.0.1.tar${NC}"
    
    echo "📋 Hex Package Contents:"
    tar -tf playwriter-0.0.1.tar
    
    echo -e "${YELLOW}📊 Package Statistics:${NC}"
    echo "   Package size: $(ls -lh playwriter-0.0.1.tar | awk '{print $5}')"
    
    # Extract and check the actual file contents
    if tar -xf playwriter-0.0.1.tar contents.tar.gz 2>/dev/null; then
        echo "   Source files: $(tar -tzf contents.tar.gz | wc -l)"
        rm -f contents.tar.gz 2>/dev/null
    fi
else
    echo -e "${RED}❌ Package file not found${NC}"
    exit 1
fi

echo

echo "✅ Version Verification..."
VERSION_IN_MIX=$(grep '@version "0.0.1"' mix.exs)
if [ -n "$VERSION_IN_MIX" ]; then
    echo -e "${GREEN}✅ Version 0.0.1 in mix.exs${NC}"
else
    echo -e "${RED}❌ Version not found in mix.exs${NC}"
    exit 1
fi

echo "🔗 Link Verification..."
grep -q "nshkrdotcom/playwriter" README.md
check_step "GitHub repository link in README"

grep -q "hexdocs.pm/playwriter" README.md  
check_step "HexDocs link in README"

grep -q "hex.pm/packages/playwriter" README.md
check_step "Hex package link in README"

echo "📝 Documentation Verification..."
grep -q "@moduledoc" lib/playwriter.ex
check_step "Main module documented"

grep -q "NSHkr" lib/playwriter.ex
check_step "Author attribution in documentation"

echo "🎯 CLI Verification..."
./playwriter help > /dev/null 2>&1
check_step "CLI help command works"

echo
echo -e "${GREEN}🎉 ALL CHECKS PASSED!${NC}"
echo -e "${GREEN}📦 Playwriter v0.0.1 is ready for Hex release${NC}"
echo
echo "📋 Next Steps:"
echo "1. Run: mix hex.publish"
echo "2. Follow prompts to publish to Hex"
echo "3. Verify at: https://hex.pm/packages/playwriter"
echo "4. Check docs at: https://hexdocs.pm/playwriter"
echo
echo "🏷️  Repository: https://github.com/nshkrdotcom/playwriter"
echo "👤 Author: NSHkr"
echo "📄 License: MIT"