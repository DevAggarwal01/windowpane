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

Hooks.ImageCropper = {
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
          width: 400,
          height: 600,
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
    document.addEventListener('cropper:crop-and-upload', this.handleCropAndUpload);
    document.addEventListener('cropper:close', this.handleCloseCropper);
    
    // Set up file input if it exists
    this.setupFileInput();
  },
  
  updated() {
    this.setupFileInput();
  },
  
  destroyed() {
    this.destroyCropper();
    document.removeEventListener('cropper:crop-and-upload', this.handleCropAndUpload);
    document.removeEventListener('cropper:close', this.handleCloseCropper);
  },
  
  setupFileInput() {
    const fileInput = document.getElementById('cover-file-input');
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
        this.pushEvent("show_cropper_modal", {});
      } catch (error) {
        console.warn("Failed to push show_cropper_modal event:", error);
        return;
      }
      
      // Wait for modal to be rendered, then initialize cropper
      setTimeout(() => {
        const image = document.getElementById('cropper-image');
        if (image) {
          image.src = e.target.result;
          this.initializeCropper(image);
        }
      }, 100);
    };
    reader.readAsDataURL(file);
  },
  
  initializeCropper(imageElement) {
    if (this.cropper) {
      this.destroyCropper();
    }
    
    // Initialize Cropper.js
    this.cropper = new Cropper(imageElement, {
      aspectRatio: 2 / 3, // 2:3 aspect ratio
      viewMode: 2,
      guides: true,
      center: true,
      highlight: true,
      cropBoxMovable: true,
      cropBoxResizable: true,
      toggleDragModeOnDblclick: false,
      minCropBoxWidth: 200,
      minCropBoxHeight: 300,
      responsive: true,
      restore: false,
      checkCrossOrigin: false,
      checkOrientation: false,
      modal: true,
      background: true,
      ready: () => {
        console.log('Cropper initialized');
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
      this.pushEvent("hide_cropper_modal", {});
    } catch (error) {
      console.warn("Failed to push hide_cropper_modal event:", error);
    }
  },
  
  uploadCroppedImage(blob) {
    const formData = new FormData();
    formData.append('cover', blob, 'cropped-cover.jpg');
    formData.append('project_id', this.el.dataset.projectId);
    
    // Show uploading state
    try {
      this.pushEvent("set_uploading", { uploading: true });
    } catch (error) {
      console.warn("Failed to push set_uploading event:", error);
      return;
    }
    
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
        this.destroyCropper();
        this.hideCropperModal();
        try {
          this.pushEvent("upload_success", {});
        } catch (error) {
          console.warn("Failed to push upload_success event:", error);
        }
      } else {
        try {
          this.pushEvent("upload_error", { error: data.error });
        } catch (error) {
          console.warn("Failed to push upload_error event:", error);
        }
      }
    })
    .catch(error => {
      try {
        this.pushEvent("upload_error", { error: error.message });
      } catch (pushError) {
        console.warn("Failed to push upload_error event:", pushError);
      }
    })
    .finally(() => {
      try {
        this.pushEvent("set_uploading", { uploading: false });
      } catch (error) {
        console.warn("Failed to push set_uploading event:", error);
      }
    });
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
        this.pushEvent("show_banner_cropper_modal", {});
        
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
      this.pushEvent("hide_banner_cropper_modal", {});
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
      this.pushEvent("set_banner_uploading", { uploading: true });
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
          this.pushEvent("banner_upload_success", {});
        } catch (error) {
          console.warn("Failed to push banner_upload_success event:", error);
        }
      } else {
        try {
          this.pushEvent("banner_upload_error", { error: data.error });
        } catch (error) {
          console.warn("Failed to push banner_upload_error event:", error);
        }
      }
    })
    .catch(error => {
      try {
        this.pushEvent("banner_upload_error", { error: error.message });
      } catch (pushError) {
        console.warn("Failed to push banner_upload_error event:", pushError);
      }
    })
    .finally(() => {
      try {
        this.pushEvent("set_banner_uploading", { uploading: false });
      } catch (error) {
        console.warn("Failed to push set_banner_uploading event:", error);
      }
    });
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

