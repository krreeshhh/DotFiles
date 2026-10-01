/**
 * Hypr PiP - Universal Picture-in-Picture Background Service Worker
 * Manages browser commands (Alt+P), dynamic content script injection, and active tab messaging.
 */

// Command listener for keyboard shortcuts defined in manifest.json (Alt+P)
chrome.commands.onCommand.addListener(async (command) => {
  if (command === 'toggle-pip') {
    const [activeTab] = await chrome.tabs.query({ active: true, currentWindow: true });
    if (!activeTab || !activeTab.id) return;

    // Check if URL allows script injection (prevent errors on chrome:// or edge:// pages)
    if (activeTab.url && (activeTab.url.startsWith('chrome://') || activeTab.url.startsWith('edge://') || activeTab.url.startsWith('brave://') || activeTab.url.startsWith('about:'))) {
      return;
    }

    try {
      // Try sending message to content script
      const response = await chrome.tabs.sendMessage(activeTab.id, { action: 'togglePiP' });
      if (response && response.success) {
        console.log('[HyprPiP Background] PiP toggled successfully:', response.action);
      }
    } catch (err) {
      // If content script was not injected, inject it on the fly
      try {
        await chrome.scripting.executeScript({
          target: { tabId: activeTab.id, allFrames: true },
          files: ['content.js']
        });
        await chrome.scripting.insertCSS({
          target: { tabId: activeTab.id, allFrames: true },
          files: ['content.css']
        });
        // Retry message after injection
        await chrome.tabs.sendMessage(activeTab.id, { action: 'togglePiP' });
      } catch (injectionError) {
        console.warn('[HyprPiP Background] Script injection error:', injectionError);
      }
    }
  }
});

// Extension icon click / installation listener
chrome.runtime.onInstalled.addListener((details) => {
  console.log('[HyprPiP Background] Extension installed/updated:', details.reason);
});
