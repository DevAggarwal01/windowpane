// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"
import * as PIXI from "pixi.js";
import { Viewport } from "pixi-viewport";

// Create a global PIXI application instance
let pixiApp = null;

// Cropper.js Hook for LiveView
let Hooks = {}

Hooks.UpdatePrice = {
  mounted() {
    this.el.addEventListener('click', (e) => {
      e.preventDefault();
      const priceInput = document.getElementById('price-input');
      if (priceInput) {
        const price = priceInput.value;
        console.log('Sending price update with value:', price);
        // Use pushEventTo to target the component that has the phx-target
        const target = this.el.getAttribute('phx-target');
        if (target) {
          this.pushEventTo(target, 'update_price', { price: price });
        } else {
          this.pushEvent('update_price', { price: price });
        }
      }
    });
  }
}

Hooks.UpdateRentalPrice = {
  mounted() {
    this.el.addEventListener('click', (e) => {
      e.preventDefault();
      const rentalPriceInput = document.getElementById('rental-price-input');
      if (rentalPriceInput) {
        const price = rentalPriceInput.value;
        console.log('Sending rental price update with value:', price);
        // Use pushEventTo to target the component that has the phx-target
        const target = this.el.getAttribute('phx-target');
        if (target) {
          this.pushEventTo(target, 'update_rental_price', { price: price });
        } else {
          this.pushEvent('update_rental_price', { price: price });
        }
      }
    });
  }
}

Hooks.CoverUpload = {
  mounted() {
    this.fileInput = null;
    this.setupFileInput();
    
    // Handle the "Choose File" button click in modal
    this.handleChooseFileClick = () => {
      if (this.fileInput) {
        this.fileInput.click();
      }
    };
    
    // Add event listener for the choose file button
    document.addEventListener('cover-upload:choose-file', this.handleChooseFileClick);
  },
  
  destroyed() {
    document.removeEventListener('cover-upload:choose-file', this.handleChooseFileClick);
  },
  
  setupFileInput() {
    // Find the file input associated with this hook
    this.fileInput = this.el.querySelector('input[type="file"]') || 
                     document.getElementById('cover-file-input');
    
    if (this.fileInput) {
      this.fileInput.addEventListener('change', this.handleFileSelect.bind(this));
    }
  },
  
  handleFileSelect(event) {
    const file = event.target.files[0];
    if (!file || !file.type.startsWith('image/')) {
      this.showError('Please select a valid image file.');
      return;
    }
    
    // Create an image element to check dimensions
    const img = new Image();
    img.onload = () => {
      const aspectRatio = img.width / img.height;
      const targetRatio = 2 / 3; // 2:3 aspect ratio
      const tolerance = 0.01; // Allow small tolerance for floating point comparison
      
      console.log(`Image dimensions: ${img.width}x${img.height}`);
      console.log(`Aspect ratio: ${aspectRatio.toFixed(3)}, Target: ${targetRatio.toFixed(3)}`);
      
      if (Math.abs(aspectRatio - targetRatio) > tolerance) {
        const errorMessage = `Image must have a 2:3 aspect ratio. Your image is ${img.width}×${img.height} pixels (ratio: ${aspectRatio.toFixed(3)}). Please use an image with the correct proportions or adjust it using the aspect ratio tool.`;
        this.showError(errorMessage);
        this.resetFileInput();
        return;
      }
      
      // Aspect ratio is correct, proceed with upload
      this.uploadImage(file);
    };
    
    img.onerror = () => {
      this.showError('Could not load the selected image file. Please try a different image.');
      this.resetFileInput();
    };
    
    // Create a URL for the image to load it
    img.src = URL.createObjectURL(file);
  },
  
  uploadImage(file) {
    // Show uploading state
    this.setUploading(true);
    
    const formData = new FormData();
    formData.append('cover', file);
    formData.append('project_id', this.el.dataset.projectId);
    
    fetch(`/api/projects/${this.el.dataset.projectId}/cover`, {
      method: 'POST',
      body: formData,
      headers: {
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
      }
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        this.uploadSuccess();
      } else {
        this.showError(data.error || 'Upload failed');
      }
    })
    .catch(error => {
      this.showError(`Upload failed: ${error.message}`);
    })
    .finally(() => {
      this.setUploading(false);
      this.resetFileInput();
    });
  },
  
  setUploading(uploading) {
      try {
      this.pushEventTo(this.el, "set_uploading", { uploading: uploading });
      } catch (error) {
        console.warn("Failed to push set_uploading event:", error);
      }
  },
  
  uploadSuccess() {
    try {
      this.pushEventTo(this.el, "upload_success", {});
    } catch (error) {
      console.warn("Failed to push upload_success event:", error);
    }
  },
  
  showError(message) {
    // Show immediate visual feedback
    console.error('Cover Upload Error:', message);
    
    // Create a temporary error display in the modal
    const errorDiv = document.createElement('div');
    errorDiv.className = 'mt-4 p-3 bg-red-50 border border-red-200 rounded-md';
    errorDiv.innerHTML = `
      <div class="flex">
        <div class="flex-shrink-0">
          <svg class="h-5 w-5 text-red-400" viewBox="0 0 20 20" fill="currentColor">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
          </svg>
        </div>
        <div class="ml-3">
          <p class="text-sm text-red-800">${message}</p>
        </div>
      </div>
    `;
    
    // Find the modal content and add error message
    const modalContent = document.querySelector('#cover-upload-hook');
    if (modalContent) {
      // Remove any existing error messages
      const existingError = modalContent.querySelector('.error-message');
      if (existingError) {
        existingError.remove();
      }
      
      errorDiv.classList.add('error-message');
      modalContent.appendChild(errorDiv);
      
      // Auto-remove after 8 seconds
      setTimeout(() => {
        if (errorDiv.parentNode) {
          errorDiv.remove();
        }
      }, 8000);
    }
    
    // Also send to LiveView for server-side flash message
    try {
      this.pushEventTo(this.el, "upload_error", { error: message });
    } catch (error) {
      console.warn("Failed to push upload_error event:", error);
    }
  },
  
  resetFileInput() {
    if (this.fileInput) {
      this.fileInput.value = '';
    }
  }
};

Hooks.BannerCropper = {
  mounted() {
    this.cropper = null;
    this.fileInput = null;
    
    // Handle file input change
    this.handleFileSelect = (event) => {
      const file = event.target.files[0];
      if (file && file.type.startsWith('image/')) {
        this.showCropperModal(file);
      }
    };
    
    // Handle cropper modal events
    this.handleCropAndUpload = () => {
      if (this.cropper) {
        const canvas = this.cropper.getCroppedCanvas({
          width: 1920,
          height: 1080,
          imageSmoothingEnabled: true,
          imageSmoothingQuality: 'high'
        });
        
        canvas.toBlob((blob) => {
          this.uploadCroppedImage(blob);
        }, 'image/jpeg', 0.9);
      }
    };
    
    this.handleCloseCropper = () => {
      this.destroyCropper();
      this.hideCropperModal();
    };
    
    // Add event listeners
    document.addEventListener('banner-cropper:crop-and-upload', this.handleCropAndUpload);
    document.addEventListener('banner-cropper:close', this.handleCloseCropper);
    
    // Set up file input if it exists
    this.setupFileInput();
  },
  
  updated() {
    this.setupFileInput();
  },
  
  destroyed() {
    this.destroyCropper();
    document.removeEventListener('banner-cropper:crop-and-upload', this.handleCropAndUpload);
    document.removeEventListener('banner-cropper:close', this.handleCloseCropper);
  },
  
  setupFileInput() {
    const fileInput = document.getElementById('banner-file-input');
    if (fileInput && fileInput !== this.fileInput) {
      this.fileInput = fileInput;
      this.fileInput.addEventListener('change', this.handleFileSelect);
    }
  },
  
  showCropperModal(file) {
    const reader = new FileReader();
    reader.onload = (e) => {
      // Push event to LiveView to show modal
      try {
        this.pushEventTo(this.el, "show_banner_cropper_modal", {});
        
        // Wait for modal to be rendered, then initialize cropper
        setTimeout(() => {
          const image = document.getElementById('banner-cropper-image');
          if (image) {
            image.src = e.target.result;
            this.initializeCropper(image);
          }
        }, 100);
      } catch (error) {
        console.warn("Failed to push show_banner_cropper_modal event:", error);
      }
    };
    reader.readAsDataURL(file);
  },
  
  initializeCropper(imageElement) {
    if (this.cropper) {
      this.destroyCropper();
    }
    
    // Initialize Cropper.js
    this.cropper = new Cropper(imageElement, {
      aspectRatio: 16 / 9, // 16:9 aspect ratio
      viewMode: 2,
      guides: true,
      center: true,
      highlight: true,
      cropBoxMovable: true,
      cropBoxResizable: true,
      toggleDragModeOnDblclick: false,
      minCropBoxWidth: 320,
      minCropBoxHeight: 180,
      responsive: true,
      restore: false,
      checkCrossOrigin: false,
      checkOrientation: false,
      modal: true,
      background: true,
      ready: () => {
        console.log('Banner Cropper initialized');
      }
    });
  },
  
  destroyCropper() {
    if (this.cropper) {
      this.cropper.destroy();
      this.cropper = null;
    }
  },
  
  hideCropperModal() {
    try {
      this.pushEventTo(this.el, "hide_banner_cropper_modal", {});
    } catch (error) {
      console.warn("Failed to push hide_banner_cropper_modal event:", error);
    }
  },
  
  uploadCroppedImage(blob) {
    const formData = new FormData();
    formData.append('banner', blob, 'cropped-banner.jpg');
    formData.append('project_id', this.el.dataset.projectId);
    
    // Show uploading state
    try {
      this.pushEventTo(this.el, "set_banner_uploading", { uploading: true });
    } catch (error) {
      console.warn("Failed to push set_banner_uploading event:", error);
      return;
    }
    
    fetch(`/api/projects/${this.el.dataset.projectId}/banner`, {
      method: 'POST',
      body: formData,
      headers: {
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
      }
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        this.destroyCropper();
        this.hideCropperModal();
        try {
          this.pushEventTo(this.el, "banner_upload_success", {});
        } catch (error) {
          console.warn("Failed to push banner_upload_success event:", error);
        }
      } else {
        try {
          this.pushEventTo(this.el, "banner_upload_error", { error: data.error });
        } catch (error) {
          console.warn("Failed to push banner_upload_error event:", error);
        }
      }
    })
    .catch(error => {
      try {
        this.pushEventTo(this.el, "banner_upload_error", { error: error.message });
      } catch (pushError) {
        console.warn("Failed to push banner_upload_error event:", pushError);
      }
    })
    .finally(() => {
      try {
        this.pushEventTo(this.el, "set_banner_uploading", { uploading: false });
      } catch (error) {
        console.warn("Failed to push set_banner_uploading event:", error);
      }
    });
  }
};

Hooks.BannerUpload = {
  mounted() {
    this.fileInput = null;
    this.setupFileInput();
    
    // Handle the "Choose File" button click in modal
    this.handleChooseFileClick = () => {
      if (this.fileInput) {
        this.fileInput.click();
      }
    };
    
    // Add event listener for the choose file button
    document.addEventListener('banner-upload:choose-file', this.handleChooseFileClick);
  },
  
  destroyed() {
    document.removeEventListener('banner-upload:choose-file', this.handleChooseFileClick);
  },
  
  setupFileInput() {
    // Find the file input associated with this hook
    this.fileInput = this.el.querySelector('input[type="file"]') || 
                     document.getElementById('banner-file-input');
    
    if (this.fileInput) {
      this.fileInput.addEventListener('change', this.handleFileSelect.bind(this));
    }
  },
  
  handleFileSelect(event) {
    const file = event.target.files[0];
    if (!file || !file.type.startsWith('image/')) {
      this.showError('Please select a valid image file.');
      return;
    }
    
    // Create an image element to check dimensions
    const img = new Image();
    img.onload = () => {
      const aspectRatio = img.width / img.height;
      const targetRatio = 16 / 9; // 16:9 aspect ratio
      const tolerance = 0.01; // Allow small tolerance for floating point comparison
      
      console.log(`Image dimensions: ${img.width}x${img.height}`);
      console.log(`Aspect ratio: ${aspectRatio.toFixed(3)}, Target: ${targetRatio.toFixed(3)}`);
      
      if (Math.abs(aspectRatio - targetRatio) > tolerance) {
        const errorMessage = `Image must have a 16:9 aspect ratio. Your image is ${img.width}×${img.height} pixels (ratio: ${aspectRatio.toFixed(3)}). Please use an image with the correct proportions or adjust it using the aspect ratio tool.`;
        this.showError(errorMessage);
        this.resetFileInput();
        return;
      }
      
      // Aspect ratio is correct, proceed with upload
      this.uploadImage(file);
    };
    
    img.onerror = () => {
      this.showError('Could not load the selected image file. Please try a different image.');
      this.resetFileInput();
    };
    
    // Create a URL for the image to load it
    img.src = URL.createObjectURL(file);
  },
  
  uploadImage(file) {
    // Show uploading state
    this.setUploading(true);
    
    const formData = new FormData();
    formData.append('banner', file);
    formData.append('project_id', this.el.dataset.projectId);
    
    fetch(`/api/projects/${this.el.dataset.projectId}/banner`, {
      method: 'POST',
      body: formData,
      headers: {
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
        'Accept': 'application/json'
      }
    })
    .then(response => {
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      return response.json();
    })
    .then(data => {
      if (data.success) {
        this.uploadSuccess();
      } else {
        this.showError(data.error || 'Upload failed');
      }
    })
    .catch(error => {
      this.showError(`Upload failed: ${error.message}`);
    })
    .finally(() => {
      this.setUploading(false);
      this.resetFileInput();
    });
  },
  
  setUploading(uploading) {
    try {
      this.pushEventTo(this.el, "set_banner_uploading", { uploading: uploading });
    } catch (error) {
      console.warn("Failed to push set_banner_uploading event:", error);
    }
  },
  
  uploadSuccess() {
    try {
      this.pushEventTo(this.el, "banner_upload_success", {});
    } catch (error) {
      console.warn("Failed to push banner_upload_success event:", error);
    }
  },
  
  showError(message) {
    console.error('Banner Upload Error:', message);
    try {
      this.pushEventTo(this.el, "banner_upload_error", { error: message });
    } catch (error) {
      console.warn("Failed to push banner_upload_error event:", error);
    }
  },
  
  resetFileInput() {
    if (this.fileInput) {
      this.fileInput.value = '';
    }
  }
};

Hooks.PixiCanvas = {
  
  async mounted() {
    try {
      console.log('User logged in:', this.el.dataset.loggedIn);
      this.loggedIn = this.el.dataset.loggedIn === 'true';

      console.log('PixiCanvas mounted');
      
      // Wait a bit to ensure PIXI is loaded
      await new Promise(resolve => setTimeout(resolve, 100));
      
      console.log('PIXI available:', typeof PIXI !== 'undefined');
      console.log('Viewport available:', typeof Viewport !== 'undefined');
      
      if (typeof PIXI === 'undefined') {
        console.error('PIXI.js is not loaded');
        return;
      }
      
      const container = this.el;

      // Initialize PIXI application if not already done
      if (!pixiApp) {
        pixiApp = new PIXI.Application({
          backgroundColor: 0x000000,
          resizeTo: window,
        });
        container.appendChild(pixiApp.view);
      }

      const center = 3000;

      this.viewport = new Viewport({
        screenWidth: window.innerWidth,
        screenHeight: window.innerHeight,
        worldWidth: center * 2,
        worldHeight: center * 2,
        events: pixiApp.renderer.events,
        ticker: pixiApp.ticker,
        interaction: pixiApp.renderer.events,
      });
      const viewport = this.viewport;

      pixiApp.stage.addChild(viewport);
      viewport.drag().decelerate();
      
      // Configuration
      this.CELL_SIZE = 400;
      this.RADIUS_IN_CELLS = 2; // adjustable, like 1.5 * viewport width in cells
      this.BORDER_SIZE = 8;

      // Performance optimization properties
      this.renderedCells = this.renderedCells || new Map();
      this.loadingQueue = new Map(); // cellKey -> { id, priority, gx, gy, container }
      this.currentlyLoading = new Set(); // Track what's currently loading
      this.MAX_CONCURRENT_LOADS = 3; // Limit concurrent image loads
      this.textureCache = new Map(); // Cache loaded textures
      this.abortControllers = new Map(); // Track loading requests
      this.containerPool = []; // Object pool for containers
      this.cleanupTimeout = null;
      this.pendingIds = new Map(); // Store IDs for containers that don't exist yet
      
      // Calculate center cell coordinates properly
      this.centerCellX = Math.floor(center / this.CELL_SIZE);
      this.centerCellY = Math.floor(center / this.CELL_SIZE);
      this.CENTER_CELL_KEY = `${this.centerCellX},${this.centerCellY}`;
      
      console.log('Center coordinates:', center, 'Center cell:', this.centerCellX, this.centerCellY, 'Center key:', this.CENTER_CELL_KEY);

      // Move viewport to center BEFORE rendering cells
      viewport.moveCenter(center, center);
      
      // Wait for viewport to settle before initial render
      await new Promise(resolve => setTimeout(resolve, 50));
      
      // Initial render with explicit center coordinates
      console.log('Initial viewport center:', viewport.center.x, viewport.center.y);
      this.renderCellsAround(center, center);

      // Throttled viewport movement handling
      let moveTimeout = null;
      viewport.on('moved', () => {
        if (moveTimeout) clearTimeout(moveTimeout);
        moveTimeout = setTimeout(() => {
          console.log('Viewport moved to:', viewport.center.x, viewport.center.y);
          this.renderCellsAround(viewport.center.x, viewport.center.y);
        }, 16); // ~60fps throttling
      });

      viewport.on('moved-end', () => {
        console.log('Viewport moved-end to:', viewport.center.x, viewport.center.y);
        this.renderCellsAround(viewport.center.x, viewport.center.y);
        
        // Throttled cleanup
        if (!this.cleanupTimeout) {
          this.cleanupTimeout = setTimeout(() => {
            this.cleanupDistantTextures();
            this.cleanupTimeout = null;
          }, 2000);
        }
      });

      // Enhanced project IDs handling with priority queue
      this.handleEvent("project_ids_fetched", async ({ project_ids, keys }) => {
        console.log("Got project IDs:", project_ids, "for keys:", keys);
        console.log("# of project IDs:", project_ids.length);
        console.log("# of keys:", keys.length);
        const viewportCenter = this.viewport.center;
        const CELL_SIZE = this.CELL_SIZE;
        
        // Calculate priorities and add to queue
        for (let i = 0; i < project_ids.length; i++) {
          const key = keys[i];
          const id = project_ids[i];
          
          console.log(`Processing project ID ${id} for cell ${key}`);
          
          const container = this.renderedCells.get(key);
          
          // Skip center cell (title cell)
          if (key === this.CENTER_CELL_KEY) {
            console.log(`Skipping center cell ${key}`);
            continue;
          }
          
          if (!container) {
            console.log(`No container found for key ${key}, will queue for later`);
            // Store the ID mapping for when the container is created
            if (!this.pendingIds) this.pendingIds = new Map();
            this.pendingIds.set(key, id);
            continue;
          }
          
          if (!container.hasOwnProperty('isPlaceholder') || !container.isPlaceholder) {
            console.log(`Container for key ${key} is not a placeholder or already loaded`);
            continue;
          }
          
          // Parse cell coordinates from key
          const [gx, gy] = key.split(',').map(Number);
          
          // Calculate distance from viewport center
          const cellCenterX = (gx + 0.5) * CELL_SIZE;
          const cellCenterY = (gy + 0.5) * CELL_SIZE;
          const distance = Math.sqrt(
            Math.pow(cellCenterX - viewportCenter.x, 2) + 
            Math.pow(cellCenterY - viewportCenter.y, 2)
          );
          
          console.log(`Adding ${key} to loading queue with distance ${distance}`);
          
          this.loadingQueue.set(key, {
            id,
            priority: -distance, // Negative so closer = higher priority
            gx,
            gy,
            container
          });
        }
        
        // Process the queue
        this.processLoadingQueue();
      });
      
      console.log('PixiCanvas initialized successfully');
    } catch (error) {
      console.error('Error initializing PixiCanvas:', error);
    }
  },

  // Process loading queue by priority
  processLoadingQueue() {
    const available = this.MAX_CONCURRENT_LOADS - this.currentlyLoading.size;
    if (available <= 0 || this.loadingQueue.size === 0) return;
    
    // Sort by priority (higher = more important)
    const sortedItems = Array.from(this.loadingQueue.entries())
      .sort(([,a], [,b]) => b.priority - a.priority)
      .slice(0, available);
    
    for (const [key, item] of sortedItems) {
      this.loadingQueue.delete(key);
      this.currentlyLoading.add(key);
      
      this.convertToImageSprite(item.container, item.id)
        .finally(() => {
          this.currentlyLoading.delete(key);
          // Process more items from queue
          setTimeout(() => this.processLoadingQueue(), 10);
        });
    }
  },

  // Optimized cell rendering with better culling
  renderCellsAround(x, y) {
    console.log("renderCellsAround", x, y);
    
    const CELL_SIZE = this.CELL_SIZE;
    const RADIUS_IN_CELLS = this.RADIUS_IN_CELLS;
    const CENTER_CELL_KEY = this.CENTER_CELL_KEY;
    const viewport = this.viewport;

    const cellX = Math.floor(x / CELL_SIZE);
    const cellY = Math.floor(y / CELL_SIZE);
    
    console.log(`Rendering around cell coordinates: ${cellX}, ${cellY}`);

    // Use Sets for better performance on large datasets
    const visibleCells = new Set();
    const newCellsSet = new Set();
    const newCellKeys = [];

    // Calculate visible cells in a single pass
    for (let dx = -RADIUS_IN_CELLS; dx <= RADIUS_IN_CELLS; dx++) {
      for (let dy = -RADIUS_IN_CELLS; dy <= RADIUS_IN_CELLS; dy++) {
        const gx = cellX + dx;
        const gy = cellY + dy;
        const cellKey = `${gx},${gy}`;
        
        visibleCells.add(cellKey);

        if (!this.renderedCells.has(cellKey)) {
          newCellsSet.add(cellKey);
          newCellKeys.push({ cellKey, gx, gy });
          console.log(`New cell to render: ${cellKey} at world coords (${gx * CELL_SIZE}, ${gy * CELL_SIZE})`);
        }
      }
    }

    console.log(`Total visible cells: ${visibleCells.size}, new cells: ${newCellKeys.length}`);

    // Cancel any loading requests for cells that are no longer visible
    for (const [key] of this.renderedCells.entries()) {
      if (!visibleCells.has(key)) {
        // Cancel loading if in progress
        const abortController = this.abortControllers.get(key);
        if (abortController) {
          abortController.abort();
        }
        // Remove from loading queue
        this.loadingQueue.delete(key);
      }
    }

    // Batch fetch project IDs for new cells
    if (newCellKeys.length > 0) {
      console.log(`Fetching project IDs for keys: ${Array.from(newCellsSet)}`);
      this.pushEvent("fetch_project_ids", {
        keys: Array.from(newCellsSet)
      });
    }

    // Create containers for new cells
    for (const { cellKey, gx, gy } of newCellKeys) {
      let container;
      
      if (cellKey === CENTER_CELL_KEY) {
        console.log(`Creating title sprite for center cell: ${cellKey}`);
        container = this.createTitleSprite();
      } else {
        console.log(`Creating image sprite for cell: ${cellKey}`);
        container = this.createImageSprite();
        
        // Check if we have a pending ID for this cell
        if (this.pendingIds && this.pendingIds.has(cellKey)) {
          const id = this.pendingIds.get(cellKey);
          this.pendingIds.delete(cellKey);
          
          console.log(`Found pending ID ${id} for newly created container ${cellKey}`);
          
          // Calculate distance for priority
          const viewportCenter = this.viewport.center;
          const cellCenterX = (gx + 0.5) * CELL_SIZE;
          const cellCenterY = (gy + 0.5) * CELL_SIZE;
          const distance = Math.sqrt(
            Math.pow(cellCenterX - viewportCenter.x, 2) + 
            Math.pow(cellCenterY - viewportCenter.y, 2)
          );
          
          // Add to loading queue immediately
          this.loadingQueue.set(cellKey, {
            id,
            priority: -distance,
            gx,
            gy,
            container
          });
        }
      }

      // Position container at correct world coordinates
      const worldX = gx * CELL_SIZE;
      const worldY = gy * CELL_SIZE;
      container.x = worldX;
      container.y = worldY;
      
      console.log(`Positioning container ${cellKey} at world coords (${worldX}, ${worldY})`);
      
      viewport.addChild(container);
      this.renderedCells.set(cellKey, container);
    }
    
    // Process any newly queued items
    if (newCellKeys.length > 0) {
      setTimeout(() => this.processLoadingQueue(), 10);
    }

    // Clean up invisible cells - batch operations for better performance
    const cellsToRemove = [];
    for (const [key, container] of this.renderedCells.entries()) {
      if (!visibleCells.has(key)) {
        cellsToRemove.push([key, container]);
      }
    }

    // Remove cells in a single pass
    for (const [key, container] of cellsToRemove) {
      console.log(`Removing cell: ${key}`);
      viewport.removeChild(container);
      
      // Properly destroy container and its contents
      if (container.sprite && container.sprite.texture) {
        // Don't destroy cached textures, just the sprite
        container.sprite.destroy({ texture: false, baseTexture: false });
      }
      container.destroy({ children: true });
      
      this.renderedCells.delete(key);
    }
    
    console.log(`Render complete. Total rendered cells: ${this.renderedCells.size}`);
  },

  // Object pooling for containers
  getPooledContainer() {
    const container = this.containerPool.pop() || new PIXI.Container();
    container.removeChildren();
    return container;
  },

  returnToPool(container) {
    container.removeChildren();
    container.isPlaceholder = true;
    container.id = null;
    container.interactive = false;
    container.buttonMode = false;
    container.sprite = null;
    this.containerPool.push(container);
  },

  createTitleSprite() {
    const CELL_SIZE = this.CELL_SIZE;
    const BORDER_SIZE = this.BORDER_SIZE;

    const container = this.getPooledContainer();

    const titleText = new PIXI.Text('Windowpane', {
      fontSize: 48,
      fill: 0xffffff,
      align: 'center'
    });
    titleText.anchor.set(0.5);
    titleText.x = CELL_SIZE / 2;
    titleText.y = CELL_SIZE / 2 - 60;

    container.addChild(titleText);

    const buttons = [
      { label: 'Logout', url: '/users/log_out', visible: this.loggedIn },
      { label: 'Browse', url: '/browse', visible: true },
      // { label: 'Library', url: '/library', visible: this.loggedIn },
      // { label: 'Wallet', url: '/wallet', visible: this.loggedIn },
      // { label: 'Settings', url: '/users/settings', visible: this.loggedIn }
    ];

    // Render each as a PIXI.Text link
    let visibleIndex = 0;
    buttons.forEach((btn) => {
      if (!btn.visible) return;
      
      const textBtn = new PIXI.Text(btn.label, {
        fontSize: 24,
        fill: 0x00ccff, // light blue for links
        align: 'center'
      });
      textBtn.anchor.set(0.5);
      textBtn.x = CELL_SIZE / 2;
      textBtn.y = CELL_SIZE / 2 + visibleIndex * 35; // vertical spacing
      textBtn.interactive = true;
      textBtn.buttonMode = true;

      textBtn.on('pointertap', () => {
        window.location.href = btn.url;
      });

      // Hover effect
      textBtn.on('pointerover', () => {
        textBtn.style.fill = 0xffffff;
        textBtn.style.fontWeight = 'bold';
      });
      textBtn.on('pointerout', () => {
        textBtn.style.fill = 0x00ccff;
        textBtn.style.fontWeight = 'normal';
      });

      container.addChild(textBtn);
      visibleIndex++;
    });

    return container;
  },
  
  // Create placeholder image sprite
  createImageSprite() {
    const CELL_SIZE = this.CELL_SIZE;
    const BORDER_SIZE = this.BORDER_SIZE;

    const container = this.getPooledContainer();
    container.id = null; // Will be set when we get the real ID

    // Create a placeholder graphic instead of sprite
    const placeholder = new PIXI.Graphics();
    placeholder.beginFill(0xD3D3D3); // Light gray
    placeholder.drawRect(BORDER_SIZE, BORDER_SIZE, CELL_SIZE - BORDER_SIZE * 2, CELL_SIZE - BORDER_SIZE * 2);
    placeholder.endFill();
    
    // Add loading text
    const loadingText = new PIXI.Text('Loading...', {
      fontSize: 24,
      fill: 0x666666,
      align: 'center'
    });
    loadingText.anchor.set(0.5);
    loadingText.x = CELL_SIZE / 2;
    loadingText.y = CELL_SIZE / 2;
    
    container.addChild(placeholder);
    container.addChild(loadingText);
    
    // Mark as placeholder
    container.isPlaceholder = true;
    
    return container;
  },

  // Optimized image sprite conversion with caching
  async convertToImageSprite(container, id) {
    const CELL_SIZE = this.CELL_SIZE;
    const BORDER_SIZE = this.BORDER_SIZE;
    
    try {
      // Check cache first
      let texture = this.textureCache.get(id);
      
      if (!texture) {
        // Create abort controller for this request
        const abortController = new AbortController();
        this.abortControllers.set(id, abortController);
        
        const textureUrl = `https://windowpane-images-v2.t3.storage.dev/${id}/cover?t=${Date.now()}`;
        
        try {
          // Use fetch with abort signal for better control
          const response = await fetch(textureUrl, {
            signal: abortController.signal
          });
          
          if (!response.ok) throw new Error(`HTTP ${response.status}`);
          
          const blob = await response.blob();
          const imageUrl = URL.createObjectURL(blob);
          
          texture = await PIXI.Texture.fromURL(imageUrl);
          
          // Cache the texture
          this.textureCache.set(id, texture);
          
          // Clean up blob URL after a delay to ensure texture is loaded
          setTimeout(() => URL.revokeObjectURL(imageUrl), 1000);
          
        } finally {
          this.abortControllers.delete(id);
        }
      }
      
      // Check if container still exists (user might have scrolled away)
      if (!container.parent) {
        return;
      }
      
      // Clear placeholder content
      container.removeChildren();
      
      // Create sprite with cached texture
      const sprite = new PIXI.Sprite(texture);
      sprite.x = BORDER_SIZE;
      sprite.y = BORDER_SIZE;
      sprite.width = CELL_SIZE - BORDER_SIZE * 2;
      sprite.height = CELL_SIZE - BORDER_SIZE * 2;
      container.addChild(sprite);
      container.sprite = sprite;
      
      // Set up the rest of the container (borders, interactivity)
      this.setupImageContainer(container, id);
      
      console.log("Successfully loaded image for ID:", id);
      
    } catch (error) {
      if (error.name === 'AbortError') {
        console.log("Image loading aborted for ID:", id);
        return;
      }
      
      console.error("Failed to load image for ID:", id, error);
      this.showErrorState(container, id);
    }
  },

  // Set up border and interaction for image containers
  setupImageContainer(container, id) {
    const CELL_SIZE = this.CELL_SIZE;
    
    // Add border graphics
    const borderGraphic = new PIXI.Graphics();
    container.addChild(borderGraphic);
    
    // Set up interactivity
    container.interactive = true;
    container.buttonMode = true;
    container.id = id;
    container.isPlaceholder = false;
    
    let animationFrame = null;
    let startTime = null;

    const drawBorderProgress = (elapsedRatio) => {
      const w = CELL_SIZE;
      const h = CELL_SIZE;
      const totalLength = 2 * (w + h);
      const drawLength = elapsedRatio * totalLength;

      borderGraphic.clear();
      borderGraphic.lineStyle(4, 0xF5F5DC, 1);

      let remaining = drawLength;

      // Top
      const topLen = w;
      borderGraphic.moveTo(0, 0);
      if (remaining <= topLen) {
        borderGraphic.lineTo(remaining, 0);
        return;
      } else {
        borderGraphic.lineTo(w, 0);
        remaining -= topLen;
      }

      // Right
      const rightLen = h;
      borderGraphic.moveTo(w, 0);
      if (remaining <= rightLen) {
        borderGraphic.lineTo(w, remaining);
        return;
      } else {
        borderGraphic.lineTo(w, h);
        remaining -= rightLen;
      }

      // Bottom
      const bottomLen = w;
      borderGraphic.moveTo(w, h);
      if (remaining <= bottomLen) {
        borderGraphic.lineTo(w - remaining, h);
        return;
      } else {
        borderGraphic.lineTo(0, h);
        remaining -= bottomLen;
      }

      // Left
      const leftLen = h;
      borderGraphic.moveTo(0, h);
      if (remaining <= leftLen) {
        borderGraphic.lineTo(0, h - remaining);
      } else {
        borderGraphic.lineTo(0, 0);
      }
    };

    const animate = (timestamp) => {
      if (!startTime) startTime = timestamp;
      const elapsed = timestamp - startTime;
      const duration = 3000;
      const ratio = Math.min(elapsed / duration, 1);
      drawBorderProgress(ratio);

      if (ratio < 1) {
        animationFrame = requestAnimationFrame(animate);
      } else {
        window.location.href = `/info?trailer_id=${container.id}`;
      }
    };

    container.on('pointerover', () => {
      if (animationFrame) cancelAnimationFrame(animationFrame);
      startTime = null;
      animationFrame = requestAnimationFrame(animate);
    });

    container.on('pointerout', () => {
      if (animationFrame) cancelAnimationFrame(animationFrame);
      animationFrame = null;
      startTime = null;
      borderGraphic.clear();
    });
  },

  // Display error state for failed loads
  showErrorState(container, id) {
    const CELL_SIZE = this.CELL_SIZE;
    const BORDER_SIZE = this.BORDER_SIZE;
    
    container.removeChildren();
    const errorGraphic = new PIXI.Graphics();
    errorGraphic.beginFill(0xFF6B6B);
    errorGraphic.drawRect(BORDER_SIZE, BORDER_SIZE, CELL_SIZE - BORDER_SIZE * 2, CELL_SIZE - BORDER_SIZE * 2);
    errorGraphic.endFill();
    
    const errorText = new PIXI.Text('Error loading image', {
      fontSize: 16,
      fill: 0xFFFFFF,
      align: 'center',
      wordWrap: true,
      wordWrapWidth: CELL_SIZE - BORDER_SIZE * 4
    });
    errorText.anchor.set(0.5);
    errorText.x = CELL_SIZE / 2;
    errorText.y = CELL_SIZE / 2;
    
    container.addChild(errorGraphic);
    container.addChild(errorText);
    container.isPlaceholder = false;
  },

  // Clean up distant textures to manage memory
  cleanupDistantTextures() {
    // If cache gets too large, remove textures for distant cells
    if (this.textureCache.size > 50) { // Adjust threshold as needed
      const textureIdsToRemove = [];
      
      // Simple LRU approach - remove oldest entries
      const cacheEntries = Array.from(this.textureCache.entries());
      const entriesToRemove = cacheEntries.slice(0, Math.floor(cacheEntries.length / 3));
      
      for (const [id, texture] of entriesToRemove) {
        texture.destroy(true);
        this.textureCache.delete(id);
      }
      
      console.log(`Cleaned up ${entriesToRemove.length} textures from cache`);
    }
  },
  
  destroyed() {
    // Clean up all resources when hook is destroyed
    console.log('Cleaning up PixiCanvas resources...');
    
    // Cancel all pending requests
    for (const abortController of this.abortControllers.values()) {
      abortController.abort();
    }
    this.abortControllers.clear();
    
    // Clear timeouts
    if (this.cleanupTimeout) {
      clearTimeout(this.cleanupTimeout);
    }
    
    // Destroy all cached textures
    for (const texture of this.textureCache.values()) {
      texture.destroy(true);
    }
    this.textureCache.clear();
    
    // Clean up containers
    for (const container of this.renderedCells.values()) {
      if (container.sprite && container.sprite.texture) {
        container.sprite.destroy({ texture: false, baseTexture: false });
      }
      container.destroy({ children: true });
    }
    this.renderedCells.clear();
    
    // Clear other maps
    if (this.pendingIds) {
      this.pendingIds.clear();
    }
    this.loadingQueue.clear();
    this.currentlyLoading.clear();
    
    // Clean up PIXI application
    if (pixiApp) {
      pixiApp.destroy(true);
      pixiApp = null;
    }
    
    console.log('PixiCanvas cleanup complete');
  }
};

Hooks.RegistrationSuccess = {
  mounted() {
    window.location.reload();
  }
}

// Remove the default export and keep Hooks as a regular object
// export default Hooks;

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
console.log("Hooks", Hooks);
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

