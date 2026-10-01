/**
 * Hypr PiP - Universal Picture-in-Picture Popup Logic
 */

document.addEventListener('DOMContentLoaded', async () => {
  const pipBadge = document.getElementById('pip-badge');
  const videoTitle = document.getElementById('video-title');
  const videoRes = document.getElementById('video-res');
  const statusDot = document.getElementById('status-dot');
  const statusText = document.getElementById('status-text');
  const videoTime = document.getElementById('video-time');
  const btnTogglePip = document.getElementById('btn-toggle-pip');
  const btnPipText = document.getElementById('btn-pip-text');
  const btnPlayPause = document.getElementById('btn-play-pause');
  const playPauseIcon = document.getElementById('play-pause-icon');
  const btnToggleCaptions = document.getElementById('btn-toggle-captions');

  function formatTime(seconds) {
    if (isNaN(seconds) || seconds < 0) return '00:00';
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    const hrs = Math.floor(mins / 60);
    if (hrs > 0) {
      const remMins = mins % 60;
      return `${hrs}:${remMins < 10 ? '0' : ''}${remMins}:${secs < 10 ? '0' : ''}${secs}`;
    }
    return `${mins < 10 ? '0' : ''}${mins}:${secs < 10 ? '0' : ''}${secs}`;
  }

  async function getActiveTab() {
    const [tab] = await chrome.tabs.query({ active: true, currentWindow: true });
    return tab;
  }

  async function updateUI() {
    const tab = await getActiveTab();
    if (!tab || !tab.id) {
      videoTitle.textContent = 'No active tab found';
      statusText.textContent = 'Disconnected';
      return;
    }

    if (tab.url && (tab.url.startsWith('chrome://') || tab.url.startsWith('edge://') || tab.url.startsWith('brave://') || tab.url.startsWith('about:'))) {
      videoTitle.textContent = 'Browser system page';
      statusText.textContent = 'PiP disabled on internal pages';
      return;
    }

    try {
      // Query content script
      let status;
      try {
        status = await chrome.tabs.sendMessage(tab.id, { action: 'getVideoStatus' });
      } catch (e) {
        // Try injecting content script if missing
        await chrome.scripting.executeScript({
          target: { tabId: tab.id, allFrames: true },
          files: ['content.js']
        });
        status = await chrome.tabs.sendMessage(tab.id, { action: 'getVideoStatus' });
      }

      if (!status || !status.hasVideo) {
        videoTitle.textContent = 'No video detected on page';
        videoRes.textContent = '--';
        statusDot.className = 'dot dot-gray';
        statusText.textContent = 'No media active';
        videoTime.textContent = '--:-- / --:--';
        pipBadge.className = 'badge badge-inactive';
        pipBadge.textContent = 'Inactive';
        btnTogglePip.disabled = true;
        btnPlayPause.disabled = true;
        btnToggleCaptions.disabled = true;
        return;
      }

      // Video detected!
      videoTitle.textContent = status.title || tab.title || 'HTML5 Video';
      videoRes.textContent = status.resolution || 'Auto';
      videoTime.textContent = `${formatTime(status.currentTime)} / ${formatTime(status.duration)}`;
      btnTogglePip.disabled = false;
      btnPlayPause.disabled = false;
      btnToggleCaptions.disabled = false;

      // Update captions button state
      if (status.captionsEnabled) {
        btnToggleCaptions.classList.add('captions-active');
        btnToggleCaptions.title = 'Subtitles/Captions: Enabled (Click to toggle)';
      } else {
        btnToggleCaptions.classList.remove('captions-active');
        btnToggleCaptions.title = 'Subtitles/Captions: Disabled (Click to toggle)';
      }

      if (status.isPiP) {
        pipBadge.className = 'badge badge-active';
        pipBadge.textContent = 'PiP Active';
        statusDot.className = 'dot dot-green';
        statusText.textContent = 'In Picture-in-Picture';
        btnPipText.textContent = 'Exit PiP';
      } else if (status.isPlaying) {
        pipBadge.className = 'badge badge-inactive';
        pipBadge.textContent = 'Ready';
        statusDot.className = 'dot dot-blue';
        statusText.textContent = 'Playing';
        btnPipText.textContent = 'Enter PiP';
      } else {
        pipBadge.className = 'badge badge-inactive';
        pipBadge.textContent = 'Ready';
        statusDot.className = 'dot dot-yellow';
        statusText.textContent = 'Paused';
        btnPipText.textContent = 'Enter PiP';
      }

      playPauseIcon.textContent = status.isPlaying ? '⏸️' : '▶️';

    } catch (err) {
      console.warn('Error updating popup state:', err);
      videoTitle.textContent = 'Unable to inspect page';
      statusText.textContent = 'Permission needed';
    }
  }

  // Handle PiP toggle
  btnTogglePip.addEventListener('click', async () => {
    const tab = await getActiveTab();
    if (!tab || !tab.id) return;

    btnTogglePip.disabled = true;
    try {
      await chrome.tabs.sendMessage(tab.id, { action: 'togglePiP' });
      setTimeout(async () => {
        await updateUI();
        window.close();
      }, 150);
    } catch (err) {
      console.error('Failed to toggle PiP from popup:', err);
      btnTogglePip.disabled = false;
    }
  });

  // Handle Play / Pause
  btnPlayPause.addEventListener('click', async () => {
    const tab = await getActiveTab();
    if (!tab || !tab.id) return;

    try {
      await chrome.tabs.sendMessage(tab.id, { action: 'togglePlayPause' });
      setTimeout(updateUI, 100);
    } catch (err) {}
  });

  // Handle Subtitle/Caption Toggle
  btnToggleCaptions.addEventListener('click', async () => {
    const tab = await getActiveTab();
    if (!tab || !tab.id) return;

    try {
      const resp = await chrome.tabs.sendMessage(tab.id, { action: 'toggleCaptions' });
      if (resp && resp.captionsEnabled !== undefined) {
        if (resp.captionsEnabled) {
          btnToggleCaptions.classList.add('captions-active');
        } else {
          btnToggleCaptions.classList.remove('captions-active');
        }
      }
      setTimeout(updateUI, 100);
    } catch (err) {}
  });

  // Initial UI refresh
  await updateUI();
  // Poll every 1s while popup is open to keep timestamp/status synced
  setInterval(updateUI, 1000);
});
