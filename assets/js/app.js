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
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"

// Establish Phoenix Socket and LiveView configuration.
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import { hooks as colocatedHooks } from "phoenix-colocated/fittrack"
import topbar from "../vendor/topbar"
import Chart from "chart.js/auto"

// ---- Custom Hooks ----------------------------------------------------------

const Hooks = {
  ...colocatedHooks,

  // Toggle password visibility for Design B login UI
  PasswordToggle: {
    mounted() {
      const input = this.el.querySelector("[data-password-input]")
      const btn = this.el.querySelector("[data-password-toggle]")

      if (!input || !btn) return

      btn.addEventListener("click", () => {
        const show = input.type === "password"
        input.type = show ? "text" : "password"
        btn.setAttribute("aria-label", show ? "Hide password" : "Show password")
      })
    },
  },

  // Chart hooks for dashboard
  PersonalBestsChart: {
    mounted() {
      const data = JSON.parse(this.el.dataset.chartData)
      const ctx = this.el.getContext('2d')

      new Chart(ctx, {
        type: 'bar',
        data: data,
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            legend: {
              display: false
            }
          },
          scales: {
            y: {
              beginAtZero: true,
              title: {
                display: true,
                text: 'Weight (lbs)'
              }
            },
            x: {
              title: {
                display: true,
                text: 'Exercises'
              }
            }
          }
        }
      })
    }
  },

  VolumeChart: {
    mounted() {
      const data = JSON.parse(this.el.dataset.chartData)
      const ctx = this.el.getContext('2d')

      new Chart(ctx, {
        type: 'line',
        data: data,
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            legend: {
              display: false
            }
          },
          scales: {
            y: {
              beginAtZero: true,
              title: {
                display: true,
                text: 'Volume (lbs)'
              }
            },
            x: {
              title: {
                display: true,
                text: 'Date'
              }
            }
          }
        }
      })
    }
  },

  ExerciseProgressChart: {
    mounted() {
      const data = JSON.parse(this.el.dataset.chartData)
      const ctx = this.el.getContext('2d')

      new Chart(ctx, {
        type: 'line',
        data: data,
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            legend: {
              display: true
            }
          },
          scales: {
            y: {
              beginAtZero: true,
              title: {
                display: true,
                text: 'Weight (lbs)'
              }
            },
            x: {
              title: {
                display: true,
                text: 'Date'
              }
            }
          }
        }
      })
    }
  },

  WorkoutPlanDragDrop: {
    mounted() {
      this.el.addEventListener('dragstart', (event) => {
        const target = event.target.closest('.draggable-item')
        if (!target) return

        const itemId = target.dataset.itemId
        const itemType = target.dataset.itemType || 'exercise'

        if (itemId) {
          event.dataTransfer.setData('text/item-id', itemId)
          event.dataTransfer.setData('text/item-type', itemType)
          event.dataTransfer.effectAllowed = 'copy'
        }
      })
    }
  },

  DropZone: {
    mounted() {
      this.el.addEventListener('dragover', (event) => {
        event.preventDefault()
        this.el.classList.add('border-primary', 'bg-primary/10')
      })

      this.el.addEventListener('dragleave', () => {
        this.el.classList.remove('border-primary', 'bg-primary/10')
      })

      this.el.addEventListener('drop', (event) => {
        event.preventDefault()
        this.el.classList.remove('border-primary', 'bg-primary/10')

        const itemId = event.dataTransfer.getData('text/item-id')
        const itemType = event.dataTransfer.getData('text/item-type')

        if (itemId) {
          this.pushEvent('add_item_to_day', {
            item_id: itemId,
            item_type: itemType,
            day: this.el.dataset.day
          })
        }
      })
    }
  },

  BarcodeImport: {
    mounted() {
      this.input = this.el.querySelector("[data-barcode-input]")
      this.cameraButton = this.el.querySelector("[data-open-camera]")
      this.fileButton = this.el.querySelector("[data-open-file]")
      this.status = this.el.querySelector("[data-barcode-status]")
      this.detector = null

      this.supported = "BarcodeDetector" in window
      this.updateStatus(
        this.supported
          ? "Scanner ready. Use the camera or pick a barcode photo."
          : "Direct camera scanning is not supported in this browser. You can still paste a barcode manually."
      )

      if (this.supported) {
        try {
          this.detector = new window.BarcodeDetector({
            formats: ["ean_13", "ean_8", "upc_a", "upc_e", "code_128"],
          })
        } catch (_error) {
          this.detector = new window.BarcodeDetector()
        }
      }

      this.cameraButton?.addEventListener("click", () => this.input?.click())
      this.fileButton?.addEventListener("click", () => this.input?.click())
      this.input?.addEventListener("change", (event) => this.handleFileChange(event))
    },

    updateStatus(message) {
      if (this.status) this.status.textContent = message
    },

    async handleFileChange(event) {
      const [file] = event.target.files || []

      if (!file) return

      if (!this.detector) {
        this.pushEvent("barcode_scan_error", {
          message: "This browser cannot scan barcodes from the camera. Paste the barcode manually instead.",
        })
        event.target.value = ""
        return
      }

      this.updateStatus("Scanning image for a barcode…")

      try {
        const bitmap = await createImageBitmap(file)
        const matches = await this.detector.detect(bitmap)
        const barcode = matches.find((match) => match.rawValue)?.rawValue

        if (barcode) {
          this.updateStatus(`Barcode detected: ${barcode}`)
          this.pushEvent("barcode_detected", { barcode })
        } else {
          this.updateStatus("No barcode detected. Try a sharper image or paste the code manually.")
          this.pushEvent("barcode_scan_error", {
            message: "No barcode was detected in that image. Try a clearer photo or enter it manually.",
          })
        }
      } catch (_error) {
        this.updateStatus("Scanning failed. You can still paste the barcode manually.")
        this.pushEvent("barcode_scan_error", {
          message: "The browser could not scan that image. Try another photo or enter the barcode manually.",
        })
      } finally {
        event.target.value = ""
      }
    },
  },

  ScreenshotImport: {
    mounted() {
      this.input = this.el.querySelector("[data-screenshot-input]")
      this.openButton = this.el.querySelector("[data-open-screenshot]")
      this.status = this.el.querySelector("[data-screenshot-status]")
      this.enabled = this.el.dataset.enabled !== "false"
      this.disabledMessage =
        this.el.dataset.disabledMessage ||
        "Screenshot import needs OPENAI_API_KEY before it can parse images."

      if (!this.enabled) {
        this.updateStatus(this.disabledMessage)
        return
      }

      this.openButton?.addEventListener("click", () => this.input?.click())
      this.input?.addEventListener("change", (event) => this.handleFile(event))

      this.handlePaste = (event) => {
        const imageItem = Array.from(event.clipboardData?.items || []).find((item) =>
          item.type.startsWith("image/")
        )

        if (!imageItem) return

        event.preventDefault()
        const file = imageItem.getAsFile()
        if (file) this.readFile(file)
      }

      this.el.addEventListener("paste", this.handlePaste)
      this.updateStatus("Upload a screenshot or paste one from your clipboard.")
    },

    destroyed() {
      if (this.handlePaste) this.el.removeEventListener("paste", this.handlePaste)
    },

    updateStatus(message) {
      if (this.status) this.status.textContent = message
    },

    handleFile(event) {
      const [file] = event.target.files || []
      if (!file) return

      this.readFile(file, "upload")
      event.target.value = ""
    },

    async readFile(file, source = "upload") {
      if (!file.type.startsWith("image/")) {
        this.pushEvent("screenshot_import_error", {
          message: "Choose a valid image screenshot before importing.",
        })
        return
      }

      this.updateStatus("Reading screenshot…")

      const sourceImageMetadata = await this.buildSourceImageMetadata(file, source)
      const reader = new FileReader()

      reader.onload = () => {
        this.updateStatus("Sending screenshot for parsing…")
        this.pushEvent("screenshot_selected", {
          data_url: reader.result,
          source_image_metadata: sourceImageMetadata,
        })
      }

      reader.onerror = () => {
        this.updateStatus("Screenshot import failed. Try another image.")
        this.pushEvent("screenshot_import_error", {
          message: "The screenshot could not be read. Try another image.",
        })
      }

      reader.readAsDataURL(file)
    },

    async buildSourceImageMetadata(file, source) {
      const metadata = {
        source,
        filename: file.name || null,
        mime_type: file.type || null,
        byte_size: file.size || null,
        last_modified: file.lastModified || null,
      }

      try {
        const dimensions = await this.readImageDimensions(file)
        return { ...metadata, ...dimensions }
      } catch (_error) {
        return metadata
      }
    },

    readImageDimensions(file) {
      return new Promise((resolve, reject) => {
        const objectUrl = URL.createObjectURL(file)
        const image = new Image()

        image.onload = () => {
          resolve({ width: image.naturalWidth, height: image.naturalHeight })
          URL.revokeObjectURL(objectUrl)
        }

        image.onerror = () => {
          reject(new Error("image dimensions unavailable"))
          URL.revokeObjectURL(objectUrl)
        }

        image.src = objectUrl
      })
    },
  },

  RestTimer: {
    mounted() {
      const display = this.el.querySelector('[data-timer-display]')
      const restore = this.el.querySelector('[data-rest-input]')
      const startBtn = this.el.querySelector('[data-start-rest]')
      const stopBtn = this.el.querySelector('[data-stop-rest]')
      const resetBtn = this.el.querySelector('[data-reset-stopwatch]')
      const toggleBtn = this.el.querySelector('[data-toggle-stopwatch]')
      const swDisplay = this.el.querySelector('[data-stopwatch-display]')

      let restInterval = null
      let stopwatchInterval = null
      let stopwatchSeconds = 0

      const format = (seconds) => {
        const mins = String(Math.floor(seconds / 60)).padStart(2, '0')
        const secs = String(seconds % 60).padStart(2, '0')
        return `${mins}:${secs}`
      }

      const updateStopwatch = () => {
        stopwatchSeconds += 1
        swDisplay.textContent = format(stopwatchSeconds)
      }

      startBtn.addEventListener('click', () => {
        const total = Number(restore.value) || 60
        let remaining = total

        clearInterval(restInterval)
        display.textContent = format(remaining)

        restInterval = setInterval(() => {
          remaining -= 1
          display.textContent = format(remaining)

          if (remaining <= 0) {
            clearInterval(restInterval)
            display.textContent = '00:00'
          }
        }, 1000)
      })

      stopBtn.addEventListener('click', () => {
        clearInterval(restInterval)
      })

      toggleBtn.addEventListener('click', () => {
        if (!stopwatchInterval) {
          stopwatchInterval = setInterval(updateStopwatch, 1000)
          toggleBtn.textContent = 'Pause Stopwatch'
        } else {
          clearInterval(stopwatchInterval)
          stopwatchInterval = null
          toggleBtn.textContent = 'Start Stopwatch'
        }
      })

      resetBtn.addEventListener('click', () => {
        clearInterval(stopwatchInterval)
        stopwatchInterval = null
        stopwatchSeconds = 0
        swDisplay.textContent = '00:00'
        toggleBtn.textContent = 'Start Stopwatch'
      })
    }
  }
}

// ---------------------------------------------------------------------------

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")

const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: { _csrf_token: csrfToken },
  hooks: Hooks,
})

// Show progress bar on live navigation and form submits
topbar.config({ barColors: { 0: "#29d" }, shadowColor: "rgba(0, 0, 0, .3)" })
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({ detail: reloader }) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => (keyDown = e.key))
    window.addEventListener("keyup", _e => (keyDown = null))
    window.addEventListener(
      "click",
      e => {
        if (keyDown === "c") {
          e.preventDefault()
          e.stopImmediatePropagation()
          reloader.openEditorAtCaller(e.target)
        } else if (keyDown === "d") {
          e.preventDefault()
          e.stopImmediatePropagation()
          reloader.openEditorAtDef(e.target)
        }
      },
      true
    )

    window.liveReloader = reloader
  })
}
