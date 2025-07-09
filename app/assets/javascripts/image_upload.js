// Image Upload with Drag and Drop functionality
class ImageUpload {
  constructor() {
    this.uploadArea = document.getElementById('image-upload-area');
    this.fileInput = document.getElementById('image-input');
    this.previewsContainer = document.getElementById('image-previews');
    this.uploadPrompt = document.getElementById('upload-prompt');
    this.deleteContainer = document.getElementById('delete-images-container');
    this.selectedFiles = [];
    this.deletedImageIds = [];
    this.maxFiles = 5;
    
    if (!this.uploadArea) return; // Exit if elements don't exist
    
    this.existingImages = document.querySelectorAll('.existing-image').length;
    this.init();
  }
  
  init() {
    this.bindEvents();
    this.updateUploadPrompt();
  }
  
  bindEvents() {
    // Click to upload
    this.uploadArea.addEventListener('click', () => {
      const remainingSlots = this.maxFiles - this.existingImages - this.selectedFiles.length;
      if (remainingSlots > 0) {
        this.fileInput.click();
      }
    });

    // File input change
    this.fileInput.addEventListener('change', (e) => {
      this.handleFiles(e.target.files);
    });

    // Drag and drop
    this.uploadArea.addEventListener('dragover', (e) => {
      e.preventDefault();
      this.uploadArea.classList.add('drag-over');
    });

    this.uploadArea.addEventListener('dragleave', (e) => {
      e.preventDefault();
      this.uploadArea.classList.remove('drag-over');
    });

    this.uploadArea.addEventListener('drop', (e) => {
      e.preventDefault();
      this.uploadArea.classList.remove('drag-over');
      this.handleFiles(e.dataTransfer.files);
    });

    // Handle existing image deletion
    document.addEventListener('click', (e) => {
      if (e.target.closest('.delete-existing-image')) {
        this.handleExistingImageDeletion(e.target.closest('.delete-existing-image'));
      }
      if (e.target.closest('.delete-new-image')) {
        const index = parseInt(e.target.closest('.delete-new-image').dataset.index);
        this.removePreview(index);
      }
    });
  }
  
  handleExistingImageDeletion(button) {
    const imageId = button.dataset.imageId;
    const imageElement = button.closest('.existing-image');
    
    // Add to deletion list
    this.deletedImageIds.push(imageId);
    
    // Create hidden input for deletion
    const hiddenInput = document.createElement('input');
    hiddenInput.type = 'hidden';
    hiddenInput.name = 'listing[delete_image_ids][]';
    hiddenInput.value = imageId;
    this.deleteContainer.appendChild(hiddenInput);
    
    // Remove from display
    imageElement.remove();
    this.existingImages--;
    
    this.updateUploadPrompt();
  }
  
  handleFiles(files) {
    const currentTotal = this.existingImages - this.deletedImageIds.length + this.selectedFiles.length;
    const availableSlots = this.maxFiles - currentTotal;
    
    for (let i = 0; i < Math.min(files.length, availableSlots); i++) {
      const file = files[i];
      
      // Validate file type
      if (!file.type.match(/image\/(jpeg|jpg|png|webp)/)) {
        alert('Please select only JPEG, PNG, or WebP images.');
        continue;
      }
      
      // Validate file size (10MB)
      if (file.size > 10 * 1024 * 1024) {
        alert('Each image must be less than 10MB.');
        continue;
      }
      
      this.selectedFiles.push(file);
      this.createPreview(file, this.selectedFiles.length - 1);
    }
    
    this.updateFileInput();
    this.updateUploadPrompt();
    
    if (currentTotal + files.length >= this.maxFiles) {
      alert(`You can only upload up to ${this.maxFiles} images total.`);
    }
  }
  
  createPreview(file, index) {
    const reader = new FileReader();
    reader.onload = (e) => {
      const previewDiv = document.createElement('div');
      previewDiv.className = 'image-preview relative group';
      
      const isMainPhoto = index === 0 && this.existingImages === 0;
      const mainPhotoLabel = isMainPhoto ? 
        '<div class="absolute top-2 left-2 bg-white bg-opacity-90 px-2 py-1 rounded text-xs font-medium text-gray-800">Main Photo</div>' : '';
      
      previewDiv.innerHTML = `
        <img src="${e.target.result}" class="w-full h-32 object-cover rounded-lg" alt="Preview">
        <div class="absolute inset-0 bg-black bg-opacity-0 group-hover:bg-opacity-30 transition-all rounded-lg flex items-center justify-center">
          <button type="button" class="delete-new-image opacity-0 group-hover:opacity-100 bg-red-500 text-white p-2 rounded-full hover:bg-red-600 transition-all" data-index="${index}">
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"></path>
            </svg>
          </button>
        </div>
        ${mainPhotoLabel}
      `;
      this.previewsContainer.appendChild(previewDiv);
    };
    reader.readAsDataURL(file);
  }
  
  removePreview(index) {
    this.selectedFiles.splice(index, 1);
    this.updateFileInput();
    
    // Rebuild previews
    const previews = this.previewsContainer.querySelectorAll('.image-preview');
    previews.forEach(preview => preview.remove());
    
    this.selectedFiles.forEach((file, i) => this.createPreview(file, i));
    this.updateUploadPrompt();
  }
  
  updateFileInput() {
    // Create a new DataTransfer to hold our files
    const dt = new DataTransfer();
    this.selectedFiles.forEach(file => dt.items.add(file));
    this.fileInput.files = dt.files;
  }

  updateUploadPrompt() {
    const currentTotal = this.existingImages - this.deletedImageIds.length + this.selectedFiles.length;
    const remaining = this.maxFiles - currentTotal;
    
    if (remaining <= 0) {
      this.uploadPrompt.innerHTML = `
        <div class="text-gray-500">
          <p class="font-medium">Maximum images reached (${this.maxFiles})</p>
          <p class="text-sm">Remove an image to upload a new one</p>
        </div>
      `;
      this.uploadArea.style.cursor = 'not-allowed';
    } else {
      this.uploadPrompt.innerHTML = `
        <div class="mx-auto w-16 h-16 bg-gray-100 rounded-full flex items-center justify-center">
          <svg class="w-8 h-8 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M15 13l-3-3m0 0l-3 3m3-3v12"></path>
          </svg>
        </div>
        <div>
          <p class="text-lg font-medium text-gray-900">Add photos of your view</p>
          <p class="text-sm text-gray-500">Drag and drop photos here, or click to browse</p>
          <p class="text-xs text-gray-400 mt-2">Upload up to ${remaining} more image${remaining !== 1 ? 's' : ''} (JPEG, PNG, or WebP, max 10MB each)</p>
        </div>
      `;
      this.uploadArea.style.cursor = 'pointer';
    }
  }
}

// Initialize when DOM is loaded
document.addEventListener('DOMContentLoaded', function() {
  new ImageUpload();
});
