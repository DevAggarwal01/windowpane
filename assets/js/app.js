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
import "../css/app.css"

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

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
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

