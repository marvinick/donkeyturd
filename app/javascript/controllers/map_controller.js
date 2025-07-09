import { Controller } from "@hotwired/stimulus"
import L from "leaflet"

// Connects to data-controller="map"
export default class extends Controller {
  static values = { 
    latitude: Number, 
    longitude: Number, 
    zoom: Number,
    listings: Array,
    showMarker: Boolean
  }

  connect() {
    // Initialize the map
    this.map = L.map(this.element, {
      center: [this.latitudeValue || 40.7128, this.longitudeValue || -74.0060], // Default to NYC
      zoom: this.zoomValue || 13,
      scrollWheelZoom: true
    })

    // Add tile layer (OpenStreetMap)
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '© <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
      maxZoom: 18,
    }).addTo(this.map)

    // Add markers if we have listings data
    if (this.hasListingsValue && this.listingsValue.length > 0) {
      this.addListingMarkers()
    } else if (this.hasShowMarkerValue && this.showMarkerValue) {
      // Single listing marker
      this.addSingleMarker()
    }

    // Enable location picker for forms (check if we're in a form context)
    if (this.element.closest('form')) {
      this.enableLocationPicker()
    }

    // Resize map when container size changes
    setTimeout(() => {
      this.map.invalidateSize()
    }, 100)
  }

  disconnect() {
    if (this.map) {
      this.map.remove()
    }
  }

  addSingleMarker() {
    if (!this.latitudeValue || !this.longitudeValue) return

    const marker = L.marker([this.latitudeValue, this.longitudeValue])
      .addTo(this.map)
    
    // Add popup if there's additional data
    const title = this.element.dataset.title
    const address = this.element.dataset.address
    
    if (title || address) {
      const popupContent = `
        ${title ? `<strong>${title}</strong><br>` : ''}
        ${address ? address : ''}
      `
      marker.bindPopup(popupContent)
    }
  }

  addListingMarkers() {
    const bounds = []

    this.listingsValue.forEach(listing => {
      if (!listing.latitude || !listing.longitude) return

      // Create different marker styles for imported vs manual listings
      let marker
      if (listing.external_source && listing.external_source !== 'manual') {
        // Create custom icon for imported listings
        const importedIcon = L.divIcon({
          className: 'custom-marker imported-marker',
          html: `<div class="marker-pin imported" title="Imported from ${listing.external_source}">
                   <svg class="w-4 h-4" fill="white" viewBox="0 0 24 24">
                     <path d="M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5c-1.38 0-2.5-1.12-2.5-2.5s1.12-2.5 2.5-2.5 2.5 1.12 2.5 2.5-1.12 2.5-2.5 2.5z"/>
                   </svg>
                 </div>`,
          iconSize: [30, 30],
          iconAnchor: [15, 30]
        })
        marker = L.marker([listing.latitude, listing.longitude], { icon: importedIcon })
      } else {
        // Regular marker for manual listings
        marker = L.marker([listing.latitude, listing.longitude])
      }

      marker.addTo(this.map)

      // Create enhanced popup content
      const sourceLabel = listing.external_source && listing.external_source !== 'manual' 
        ? `<span class="inline-block bg-blue-100 text-blue-800 text-xs px-2 py-1 rounded mb-2">
             📍 Imported from ${listing.external_source.replace('_', ' ').replace(/\b\w/g, l => l.toUpperCase())}
           </span><br>` 
        : ''

      const popupContent = `
        <div class="map-popup">
          ${sourceLabel}
          <strong class="block text-sm font-semibold mb-1">${listing.title}</strong>
          ${listing.address ? `<p class="text-xs text-gray-600 mb-2">${listing.address}</p>` : ''}
          ${listing.view_type ? `<span class="inline-block bg-green-100 text-green-800 text-xs px-2 py-1 rounded mb-2">${listing.view_type}</span>` : ''}
          <br>
          <a href="/listings/${listing.id}" class="text-blue-600 hover:text-blue-800 text-xs font-medium">View Details →</a>
        </div>
      `

      marker.bindPopup(popupContent)
      bounds.push([listing.latitude, listing.longitude])
    })

    // Fit map to show all markers
    if (bounds.length > 1) {
      this.map.fitBounds(bounds, { padding: [20, 20] })
    } else if (bounds.length === 1) {
      this.map.setView(bounds[0], 13)
    }
  }

  // Method to update marker position (for form use)
  updateMarker(lat, lng) {
    if (this.marker) {
      this.map.removeLayer(this.marker)
    }

    this.marker = L.marker([lat, lng]).addTo(this.map)
    this.map.setView([lat, lng], 13)

    // Update hidden form fields if they exist
    const latField = document.querySelector('input[name*="latitude"]')
    const lngField = document.querySelector('input[name*="longitude"]')
    
    if (latField) latField.value = lat
    if (lngField) lngField.value = lng
    
    // Update coordinates display
    const coordsDisplay = document.getElementById('coordinates-display')
    if (coordsDisplay) {
      coordsDisplay.textContent = `Coordinates: ${lat.toFixed(4)}, ${lng.toFixed(4)}`
    }
  }

  // Allow clicking on map to set location (for forms)
  enableLocationPicker() {
    this.map.on('click', (e) => {
      this.updateMarker(e.latlng.lat, e.latlng.lng)
    })

    // Add instruction text
    const instruction = L.control({ position: 'topright' })
    instruction.onAdd = () => {
      const div = L.DomUtil.create('div', 'leaflet-control-custom')
      div.innerHTML = '<div class="bg-white p-2 rounded shadow text-xs">Click to set location</div>'
      return div
    }
    instruction.addTo(this.map)
  }
}
