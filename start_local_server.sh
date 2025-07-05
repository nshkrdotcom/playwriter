#!/bin/bash

echo "Starting a local Playwright server in WSL..."
echo "This is an alternative approach that runs the server locally in WSL"
echo

# Check if Node.js is installed in WSL
if ! command -v node &> /dev/null; then
    echo "Node.js is not installed in WSL. Installing..."
    curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

# Create a temporary directory
TEMP_DIR="/tmp/playwright-server"
mkdir -p "$TEMP_DIR"
cd "$TEMP_DIR"

# Create package.json
cat > package.json <<EOF
{
  "name": "playwright-server",
  "version": "1.0.0",
  "dependencies": {
    "playwright": "latest"
  }
}
EOF

# Install Playwright
echo "Installing Playwright..."
npm install

# Install browsers
echo "Installing browsers..."
npx playwright install chromium
npx playwright install firefox

# The browsers installed in WSL will run with Xvfb (virtual display)
# But we want to use the Windows browsers instead

echo
echo "Starting Playwright server on port 3333..."
echo "This server will be accessible at ws://localhost:3333/"
echo
echo "Press Ctrl+C to stop the server"
echo

# Start the server
npx playwright run-server --port 3333