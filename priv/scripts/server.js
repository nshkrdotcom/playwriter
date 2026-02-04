// Playwriter Windows Server
// Run with: node server.js [port]

const { chromium } = require('playwright');

const PORT = parseInt(process.argv[2]) || 3337;

async function main() {
  console.log(`Starting Playwright server on port ${PORT}...`);

  const server = await chromium.launchServer({
    headless: false,
    port: PORT,
  });

  const wsEndpoint = server.wsEndpoint();
  console.log(`Server running at: ${wsEndpoint}`);
  console.log('Press Ctrl+C to stop');

  // Handle shutdown
  process.on('SIGINT', async () => {
    console.log('\nShutting down...');
    await server.close();
    process.exit(0);
  });

  process.on('SIGTERM', async () => {
    console.log('\nShutting down...');
    await server.close();
    process.exit(0);
  });
}

main().catch(err => {
  console.error('Failed to start server:', err);
  process.exit(1);
});
