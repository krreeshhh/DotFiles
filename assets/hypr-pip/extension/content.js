/**
 * Hypr PiP - Universal Picture-in-Picture Content Script
 * Handles intelligent video detection, Shadow DOM traversal, native PiP invocation,
 * real-time caption/subtitle synchronization into native PiP, and keyboard shortcut handling (Alt+P).
 */

(() => {
  // Prevent duplicate injection in the same frame
  if (window.__hyprPipInjected) return;
  window.__hyprPipInjected = true;

  let toastTimeout = null;
  let captionsEnabled = true;
  let activeCaptionSync = null;

  /**
   * Display a non-intrusive sleek toast notification on the page
   */
  function showToast(message, type = 'info', duration = 2400) {
    let toast = document.getElementById('hypr-pip-toast');
    if (!toast) {
      toast = document.createElement('div');
      toast.id = 'hypr-pip-toast';
      document.body.appendChild(toast);
    }

    const icons = {
      success: '✨',
      warning: '⚠️',
      error: '❌',
      info: '📺',
      caption: '💬'
    };

    toast.className = `hypr-pip-${type}`;
    toast.innerHTML = `<span class="hypr-pip-icon">${icons[type] || '📺'}</span><span>${message}</span>`;
    
    // Trigger animation
    requestAnimationFrame(() => {
      toast.classList.add('hypr-pip-show');
    });

    if (toastTimeout) clearTimeout(toastTimeout);
    toastTimeout = setTimeout(() => {
      toast.classList.remove('hypr-pip-show');
    }, duration);
  }

  /**
   * Real-time Caption & Subtitle Synchronizer for Native Picture-in-Picture
   * Converts DOM-based subtitles (YouTube, Netflix, Video.js, custom players)
   * and WebVTT tracks into native TextTrack cues displayed directly inside the PiP window.
   */
  class CaptionSynchronizer {
    constructor(video) {
      this.video = video;
      this.track = null;
      this.observer = null;
      this.lastText = '';
      this.activeCue = null;
      this.initTrack();
      this.startObserving();
    }

    initTrack() {
      try {
        if (!this.video.addTextTrack) return;

        // Check if our track already exists
        for (let i = 0; i < this.video.textTracks.length; i++) {
          const t = this.video.textTracks[i];
          if (t.label === 'Hypr PiP Subtitles' || t.label === 'Hypr PiP Captions') {
            this.track = t;
            this.track.mode = captionsEnabled ? 'showing' : 'hidden';
            return;
          }
        }

        // Also enable any native tracks if present
        for (let i = 0; i < this.video.textTracks.length; i++) {
          const t = this.video.textTracks[i];
          if (t.kind === 'subtitles' || t.kind === 'captions') {
            if (captionsEnabled && t.mode === 'disabled') {
              t.mode = 'showing';
            }
          }
        }

        this.track = this.video.addTextTrack('subtitles', 'Hypr PiP Subtitles', 'en');
        this.track.mode = captionsEnabled ? 'showing' : 'hidden';
      } catch (e) {
        console.warn('[HyprPiP] TextTrack init error:', e);
      }
    }

    setMode(enabled) {
      if (this.track) {
        this.track.mode = enabled ? 'showing' : 'hidden';
      }
      // Sync other subtitle tracks
      try {
        for (let i = 0; i < this.video.textTracks.length; i++) {
          const t = this.video.textTracks[i];
          if (t.kind === 'subtitles' || t.kind === 'captions') {
            t.mode = enabled ? 'showing' : 'hidden';
          }
        }
      } catch (e) {}
    }

    pushCaptionText(rawText) {
      if (!this.track || !captionsEnabled) return;
      const text = (rawText || '').trim().replace(/\s+/g, ' ');
      if (!text || text === this.lastText) return;

      this.lastText = text;
      const now = this.video.currentTime;

      // Clean up old / expired cues to keep track lightweight
      try {
        if (this.track.cues) {
          for (let i = this.track.cues.length - 1; i >= 0; i--) {
            const cue = this.track.cues[i];
            if (cue.endTime <= now || (now - cue.startTime) > 10) {
              this.track.removeCue(cue);
            }
          }
        }
      } catch (e) {}

      // Create new VTTCue positioned at bottom
      try {
        if (typeof VTTCue !== 'undefined') {
          const cue = new VTTCue(now, now + 3.2, text);
          cue.align = 'center';
          cue.line = -2;
          cue.position = 50;
          cue.size = 90;
          this.track.addCue(cue);
          this.activeCue = cue;
        }
      } catch (err) {
        console.warn('[HyprPiP] VTTCue creation error:', err);
      }
    }

    extractDOMCaptions() {
      // 1. YouTube Subtitles
      const ytSegments = document.querySelectorAll('.ytp-caption-segment, .caption-window');
      if (ytSegments.length > 0) {
        let combined = '';
        ytSegments.forEach(el => {
          if (el.textContent) combined += ' ' + el.textContent.trim();
        });
        if (combined.trim()) {
          this.pushCaptionText(combined.trim());
          return;
        }
      }

      // 2. Generic and Common HTML5 Web Players (Video.js, JWPlayer, Plyr, Coursera, Udemy)
      const genericSelectors = [
        '.vjs-text-track-display',
        '.jw-captions',
        '.plyr__captions',
        '[class*="caption-window"]',
        '[class*="caption-text"]',
        '[class*="subtitle-text"]',
        '[class*="captions-display"]',
        '[class*="subtitles-display"]'
      ];

      for (const sel of genericSelectors) {
        const el = document.querySelector(sel);
        if (el && el.textContent && el.textContent.trim()) {
          this.pushCaptionText(el.textContent.trim());
          return;
        }
      }
    }

    startObserving() {
      // Initial extraction
      this.extractDOMCaptions();

      // Observe caption container changes
      this.observer = new MutationObserver(() => {
        this.extractDOMCaptions();
      });

      const playerContainer = this.video.closest('.html5-video-player, .video-js, .jwplayer, [class*="player"]') || document.body;
      try {
        this.observer.observe(playerContainer, {
          childList: true,
          subtree: true,
          characterData: true
        });
      } catch (e) {}
    }

    destroy() {
      if (this.observer) {
        this.observer.disconnect();
        this.observer = null;
      }
    }
  }

  /**
   * Recursively collect all video elements, including those inside Shadow DOMs
   */
  function collectAllVideos(root = document, results = []) {
    if (!root) return results;

    // Search in current root
    try {
      const videos = root.querySelectorAll('video');
      for (const v of videos) {
        if (!results.includes(v)) {
          results.push(v);
        }
      }
    } catch (e) {}

    // Search inside open shadow roots
    try {
      const allElements = root.querySelectorAll('*');
      for (const el of allElements) {
        if (el.shadowRoot) {
          collectAllVideos(el.shadowRoot, results);
        }
      }
    } catch (e) {}

    return results;
  }

  /**
   * Check if a video element is visible on the screen
   */
  function isElementVisible(el) {
    if (!el || !el.getBoundingClientRect) return false;
    const rect = el.getBoundingClientRect();
    if (rect.width <= 10 || rect.height <= 10) return false;

    // Check computed styles
    try {
      const style = window.getComputedStyle(el);
      if (style.display === 'none' || style.visibility === 'hidden' || style.opacity === '0') {
        return false;
      }
    } catch (e) {}

    // Check if within or near viewport
    const winH = window.innerHeight || document.documentElement.clientHeight;
    const winW = window.innerWidth || document.documentElement.clientWidth;
    const inViewport = (
      rect.bottom > 0 &&
      rect.right > 0 &&
      rect.top < winH &&
      rect.left < winW
    );

    return inViewport;
  }

  /**
   * Calculate visible area in viewport
   */
  function getVisibleArea(el) {
    if (!el || !el.getBoundingClientRect) return 0;
    const rect = el.getBoundingClientRect();
    const winH = window.innerHeight || document.documentElement.clientHeight;
    const winW = window.innerWidth || document.documentElement.clientWidth;

    const visibleWidth = Math.max(0, Math.min(rect.right, winW) - Math.max(rect.left, 0));
    const visibleHeight = Math.max(0, Math.min(rect.bottom, winH) - Math.max(rect.top, 0));
    return visibleWidth * visibleHeight;
  }

  /**
   * Rank videos based on playback state, visibility, and size
   */
  function findBestVideo() {
    const allVideos = collectAllVideos(document);
    if (!allVideos || allVideos.length === 0) return null;

    let bestVideo = null;
    let highestScore = -1;

    for (const video of allVideos) {
      if (video.videoWidth === 0 && video.clientWidth === 0 && video.readyState === 0) {
        continue;
      }

      if (video.disablePictureInPicture) {
        video.disablePictureInPicture = false;
        video.removeAttribute('disablePictureInPicture');
      }

      const visible = isElementVisible(video);
      const isPlaying = !video.paused && !video.ended && video.readyState >= 2;
      const area = getVisibleArea(video);

      let score = 0;
      if (isPlaying) score += 1000000;
      if (visible) {
        score += 500000;
        score += Math.min(area, 400000);
      } else {
        const rawArea = (video.clientWidth || 0) * (video.clientHeight || 0);
        score += Math.min(rawArea, 100000);
      }

      if (video.duration > 0) score += 10000;
      if (isPlaying && !video.muted && video.volume > 0) score += 5000;

      if (score > highestScore) {
        highestScore = score;
        bestVideo = video;
      }
    }

    return bestVideo || allVideos[0];
  }

  /**
   * Toggle Picture-in-Picture for the best detected video
   */
  async function togglePiP() {
    if (!document.pictureInPictureEnabled && !('requestPictureInPicture' in HTMLVideoElement.prototype)) {
      showToast('Picture-in-Picture is not supported in this browser.', 'error');
      return { success: false, reason: 'unsupported' };
    }

    // If already in PiP, exit
    if (document.pictureInPictureElement) {
      try {
        await document.exitPictureInPicture();
        showToast('Exited Picture-in-Picture', 'info', 1600);
        return { success: true, action: 'exited' };
      } catch (err) {
        console.warn('[HyprPiP] Failed to exit PiP:', err);
        return { success: false, error: err.message };
      }
    }

    const video = findBestVideo();
    if (!video) {
      showToast('No compatible video found on this page.', 'warning');
      return { success: false, reason: 'not_found' };
    }

    if (video.disablePictureInPicture) {
      video.disablePictureInPicture = false;
      video.removeAttribute('disablePictureInPicture');
    }

    // Attach caption synchronization
    if (!activeCaptionSync || activeCaptionSync.video !== video) {
      if (activeCaptionSync) activeCaptionSync.destroy();
      activeCaptionSync = new CaptionSynchronizer(video);
    } else {
      activeCaptionSync.setMode(captionsEnabled);
    }

    try {
      await video.requestPictureInPicture();
      showToast('Picture-in-Picture active (Captions enabled 💬)', 'success', 1800);
      return { success: true, action: 'entered' };
    } catch (err) {
      console.warn('[HyprPiP] requestPictureInPicture error:', err);
      if (err.name === 'NotAllowedError') {
        showToast('PiP requires a user interaction or is restricted by this site.', 'warning');
      } else if (err.name === 'SecurityError') {
        showToast('Video is protected or restricted by browser security policies.', 'error');
      } else {
        showToast(`Could not enter PiP: ${err.message || 'Unknown error'}`, 'error');
      }
      return { success: false, error: err.message, name: err.name };
    }
  }

  /**
   * Toggle Captions on/off
   */
  function toggleCaptions() {
    captionsEnabled = !captionsEnabled;
    const video = document.pictureInPictureElement || findBestVideo();
    if (video) {
      if (!activeCaptionSync || activeCaptionSync.video !== video) {
        activeCaptionSync = new CaptionSynchronizer(video);
      }
      activeCaptionSync.setMode(captionsEnabled);
    }
    showToast(`PiP Captions: ${captionsEnabled ? 'ON 💬' : 'OFF 🚫'}`, 'caption', 1500);
    return { success: true, captionsEnabled };
  }

  /**
   * Get current video state for the extension popup UI
   */
  function getVideoStatus() {
    const isPiPActive = !!document.pictureInPictureElement;
    const video = document.pictureInPictureElement || findBestVideo();

    if (!video) {
      return {
        hasVideo: false,
        isPiP: false,
        isPlaying: false,
        captionsEnabled: captionsEnabled,
        title: document.title || 'No active video',
        currentTime: 0,
        duration: 0,
        resolution: ''
      };
    }

    let title = document.title;
    if (location.hostname.includes('youtube.com')) {
      const ytTitle = document.querySelector('h1.ytd-watch-metadata yt-formatted-string, #title h1');
      if (ytTitle && ytTitle.textContent) {
        title = ytTitle.textContent.trim();
      }
    }

    const width = video.videoWidth || video.clientWidth || 0;
    const height = video.videoHeight || video.clientHeight || 0;
    const resolution = (width > 0 && height > 0) ? `${width}×${height}` : '';

    return {
      hasVideo: true,
      isPiP: isPiPActive,
      isPlaying: !video.paused && !video.ended,
      isMuted: video.muted,
      captionsEnabled: captionsEnabled,
      title: title,
      currentTime: Math.floor(video.currentTime || 0),
      duration: Math.floor(video.duration || 0),
      resolution: resolution
    };
  }

  /**
   * Handle Play/Pause toggle
   */
  function togglePlayPause() {
    const video = document.pictureInPictureElement || findBestVideo();
    if (!video) return { success: false };

    if (video.paused || video.ended) {
      video.play().catch(() => {});
      return { success: true, isPlaying: true };
    } else {
      video.pause();
      return { success: true, isPlaying: false };
    }
  }

  // Keyboard shortcut listener for Alt + P in active page
  window.addEventListener('keydown', (e) => {
    if (e.altKey && (e.code === 'KeyP' || e.key === 'p' || e.key === 'P') && !e.ctrlKey && !e.metaKey && !e.shiftKey) {
      e.preventDefault();
      e.stopPropagation();
      togglePiP();
    }
  }, true);

  // Auto-synchronize captions whenever any video enters PiP
  document.addEventListener('enterpictureinpicture', (e) => {
    const video = e.target;
    if (video instanceof HTMLVideoElement) {
      if (!activeCaptionSync || activeCaptionSync.video !== video) {
        activeCaptionSync = new CaptionSynchronizer(video);
      }
      activeCaptionSync.setMode(captionsEnabled);
    }
  }, true);

  // Runtime message listener from background worker and popup UI
  if (typeof chrome !== 'undefined' && chrome.runtime && chrome.runtime.onMessage) {
    chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
      if (request.action === 'togglePiP') {
        togglePiP().then(sendResponse);
        return true;
      } else if (request.action === 'getVideoStatus') {
        sendResponse(getVideoStatus());
        return false;
      } else if (request.action === 'togglePlayPause') {
        sendResponse(togglePlayPause());
        return false;
      } else if (request.action === 'toggleCaptions') {
        sendResponse(toggleCaptions());
        return false;
      }
    });
  }

  // Single-Page-App (SPA) MutationObserver for dynamic video insertion
  const observer = new MutationObserver((mutations) => {
    for (const mutation of mutations) {
      for (const node of mutation.addedNodes) {
        if (node.nodeName === 'VIDEO') {
          if (node.disablePictureInPicture) {
            node.disablePictureInPicture = false;
            node.removeAttribute('disablePictureInPicture');
          }
        } else if (node.querySelectorAll) {
          const vids = node.querySelectorAll('video');
          for (const v of vids) {
            if (v.disablePictureInPicture) {
              v.disablePictureInPicture = false;
              v.removeAttribute('disablePictureInPicture');
            }
          }
        }
      }
    }
  });

  try {
    observer.observe(document.documentElement || document.body, {
      childList: true,
      subtree: true
    });
  } catch (e) {}

})();
