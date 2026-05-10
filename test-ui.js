const { chromium } = require('playwright');

async function testUrl(browser, url) {
    const context = await browser.newContext({ ignoreHTTPSErrors: true, permissions: ['clipboard-read', 'clipboard-write'] });
    const page = await context.newPage();
    let hasError = false;

    // Track errors from console
    page.on('console', msg => {
        if (msg.type() === 'error') {
            const text = msg.text();
            const locUrl = msg.location().url || "";
            if (text.includes("Service Worker") || text.includes("Service-Worker-Allowed")) return;
            if (text.includes("404") && (locUrl.includes("/api/") || locUrl.includes("/data/") || locUrl.includes(".csv") || text.includes(".csv"))) return;
            console.error(`[ERROR] [${url}] Console error: ${text} at ${locUrl}`);
            hasError = true;
        }
    });

    // Track uncaught exceptions
    page.on('pageerror', error => {
        console.error(`[ERROR] [${url}] Page error: ${error.message}`);
        hasError = true;
    });

    // Track network 404s
    page.on('response', response => {
        if (response.status() === 404) {
            const reqUrl = response.url();
            if (reqUrl.includes('/api/') || reqUrl.includes('/data/') || reqUrl.includes('.csv')) return;
            console.error(`[ERROR] [${url}] 404 Not Found: ${reqUrl}`);
            hasError = true;
        }
    });

    try {
        console.log(`[INFO] Navigating to ${url}`);
        await page.goto(url, { waitUntil: 'networkidle', timeout: 15000 });
    } catch (e) {
        console.error(`[ERROR] [${url}] Navigation failed: ${e.message}`);
        await context.close();
        return false;
    }

    // Wait a brief moment to allow dynamic content and fetch assets
    await page.waitForTimeout(2000);

    await context.close();
    return !hasError;
}

async function main() {
    const urls = process.argv.slice(2);
    if (urls.length === 0) {
        console.error("Usage: node test-ui.js <url1> <url2> ...");
        process.exit(1);
    }

    const browser = await chromium.launch({ 
        headless: true,
        args: [
            '--host-rules=MAP curt.wortman.ai 127.0.0.1',
            '--ignore-certificate-errors',
            '--use-fake-ui-for-media-stream',
            '--use-fake-device-for-media-stream'
        ]
    });
    let allPassed = true;

    for (const url of urls) {
        const passed = await testUrl(browser, url);
        if (passed) {
            console.log(`[PASS] ${url}`);
        } else {
            console.error(`[FAIL] ${url}`);
            allPassed = false;
        }
    }

    await browser.close();

    if (!allPassed) {
        console.error("\n[!] One or more UI tests failed due to console errors.");
        process.exit(1);
    } else {
        console.log("\n[+] All UI tests passed with no console errors.");
        process.exit(0);
    }
}

main().catch(e => {
    console.error(`Script error: ${e.message}`);
    process.exit(1);
});
