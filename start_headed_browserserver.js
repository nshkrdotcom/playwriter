const { chromium } = require('playwright');

async function startHeadedBrowserServer() {
    console.log('Starting HEADED Playwright browser server...');
    
    try {
        // Launch browser server in headed mode (visible browser windows)
        const browserServer = await chromium.launchBrowserServer({
            headless: false,  // This makes browsers visible!
            port: 3337,      // Use a different port
            // Optional: slow down operations to see what's happening
            // slowMo: 500
        });
        
        const wsEndpoint = browserServer.wsEndpoint();
        console.log(`✅ HEADED Browser Server started successfully!`);
        console.log(`📡 WebSocket endpoint: ${wsEndpoint}`);
        console.log(`🌐 Browsers will be VISIBLE when used`);
        console.log(`🛑 Press Ctrl+C to stop the server`);
        
        // Keep the server running
        process.on('SIGINT', async () => {
            console.log('\n🔄 Shutting down browser server...');
            await browserServer.close();
            console.log('✅ Browser server stopped');
            process.exit(0);
        });
        
        // Keep process alive
        await new Promise(() => {});
        
    } catch (error) {
        console.error('❌ Failed to start browser server:', error);
        process.exit(1);
    }
}

startHeadedBrowserServer();