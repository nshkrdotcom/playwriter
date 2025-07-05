// Custom Playwright WebSocket server that launches headed browsers
const { chromium, firefox } = require('playwright');
const WebSocket = require('ws');

const PORT = process.argv[2] || 3333;

console.log(`Starting custom HEADED Playwright server on port ${PORT}...`);
console.log('This server will launch VISIBLE browser windows!');

const wss = new WebSocket.Server({ 
  port: PORT,
  perMessageDeflate: false 
});

let browserInstances = new Map();
let contextInstances = new Map();
let pageInstances = new Map();

wss.on('connection', async (ws, req) => {
  console.log('New WebSocket connection received');
  
  ws.on('message', async (data) => {
    try {
      const message = JSON.parse(data.toString());
      console.log('Received:', message.method || message.type);
      
      switch(message.method) {
        case 'Browser.newContext':
          console.log('Creating NEW CONTEXT with headed browser...');
          
          // Launch a HEADED browser (visible window)
          const browser = await chromium.launch({ 
            headless: false,  // This makes it visible!
            devtools: true    // Opens dev tools
          });
          
          const context = await browser.newContext();
          
          const browserId = `browser_${Date.now()}`;
          const contextId = `context_${Date.now()}`;
          
          browserInstances.set(browserId, browser);
          contextInstances.set(contextId, context);
          
          ws.send(JSON.stringify({
            id: message.id,
            result: {
              browserId: browserId,
              contextId: contextId
            }
          }));
          break;
          
        case 'BrowserContext.newPage':
          console.log('Creating NEW PAGE...');
          const contextId = message.params?.contextId;
          const context = contextInstances.get(contextId);
          
          if (context) {
            const page = await context.newPage();
            const pageId = `page_${Date.now()}`;
            pageInstances.set(pageId, page);
            
            ws.send(JSON.stringify({
              id: message.id,
              result: { pageId: pageId }
            }));
          }
          break;
          
        case 'Page.goto':
          console.log(`Navigating to: ${message.params?.url}`);
          const pageId = message.params?.pageId;
          const page = pageInstances.get(pageId);
          
          if (page) {
            await page.goto(message.params.url);
            ws.send(JSON.stringify({
              id: message.id,
              result: {}
            }));
          }
          break;
          
        case 'Page.content':
          const pageForContent = pageInstances.get(message.params?.pageId);
          if (pageForContent) {
            const content = await pageForContent.content();
            ws.send(JSON.stringify({
              id: message.id,
              result: { content: content }
            }));
          }
          break;
          
        default:
          console.log('Unhandled method:', message.method);
          ws.send(JSON.stringify({
            id: message.id,
            result: {}
          }));
      }
      
    } catch (error) {
      console.error('Error handling message:', error);
      ws.send(JSON.stringify({
        id: message.id || 0,
        error: { message: error.message }
      }));
    }
  });
  
  ws.on('close', () => {
    console.log('WebSocket connection closed, cleaning up browsers...');
    // Clean up all browser instances
    browserInstances.forEach(async (browser) => {
      try { await browser.close(); } catch(e) {}
    });
    browserInstances.clear();
    contextInstances.clear();
    pageInstances.clear();
  });
});

console.log(`WebSocket server listening on ws://localhost:${PORT}/`);
console.log('Ready to launch VISIBLE browsers!');
console.log('Press Ctrl+C to stop the server');

// Handle graceful shutdown
process.on('SIGINT', async () => {
  console.log('\nShutting down server...');
  
  // Close all browsers
  for (const browser of browserInstances.values()) {
    try { await browser.close(); } catch(e) {}
  }
  
  wss.close();
  process.exit(0);
});