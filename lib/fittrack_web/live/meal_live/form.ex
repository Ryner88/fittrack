defmodule FittrackWeb.MealLive.Form do
  use FittrackWeb, :live_view

  alias Fittrack.Nutrition
  alias Fittrack.Nutrition.Meal

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-8">
        <div class="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <p class="text-xs uppercase tracking-[0.2em] text-base-content/50">Meal logging</p>
            <h1 class="mt-2 text-3xl font-semibold text-base-content">{@page_title}</h1>
            <p class="mt-2 max-w-2xl text-sm leading-6 text-base-content/70">
              Build a meal from your food library, review the macro totals, and save it to your nutrition dashboard.
            </p>
          </div>
          <.link
            navigate={return_path(@return_to, @meal)}
            class="inline-flex items-center justify-center rounded-full border border-base-300 px-4 py-2 text-sm font-semibold text-base-content transition hover:border-primary hover:text-primary"
          >
            <.icon name="hero-arrow-left" class="mr-2 h-4 w-4" /> Back
          </.link>
        </div>

        <div class="grid gap-8 xl:grid-cols-[minmax(0,1.4fr)_minmax(21rem,0.9fr)]">
          <section class="space-y-6">
            <div class="rounded-[2rem] border border-base-200 bg-base-100 p-6 shadow-sm">
              <.form for={@form} id="meal-form" phx-change="validate" phx-submit="save">
                <div class="grid gap-4 md:grid-cols-2">
                  <.input field={@form[:name]} type="text" label="Meal name" required />
                  <.input field={@form[:eaten_at]} type="datetime-local" label="Date & time" required />
                  <div class="md:col-span-2">
                    <.input
                      field={@form[:notes]}
                      type="textarea"
                      label="Notes"
                      placeholder="Add context like hunger, energy, or prep details"
                    />
                  </div>
                </div>

                <div class="mt-6 flex flex-wrap gap-3">
                  <button
                    type="submit"
                    phx-disable-with="Saving..."
                    class="inline-flex items-center justify-center rounded-full bg-primary px-5 py-2.5 text-sm font-semibold text-white shadow-sm transition hover:-translate-y-0.5 hover:bg-primary/90"
                  >
                    Save meal
                  </button>
                  <.link
                    navigate={return_path(@return_to, @meal)}
                    class="inline-flex items-center justify-center rounded-full border border-base-300 px-5 py-2.5 text-sm font-semibold text-base-content transition hover:border-primary hover:text-primary"
                  >
                    Cancel
                  </.link>
                </div>
              </.form>
            </div>

            <div class="rounded-[2rem] border border-base-200 bg-base-100 p-6 shadow-sm">
              <div class="flex items-center justify-between gap-4">
                <div>
                  <h2 class="text-xl font-semibold text-base-content">Meal items</h2>
                  <p class="mt-1 text-sm text-base-content/70">
                    Each item updates your meal totals immediately.
                  </p>
                </div>
                <span class="rounded-full border border-base-200 bg-base-50 px-3 py-1 text-xs font-semibold uppercase tracking-[0.2em] text-base-content/60">
                  {length(@meal_items)} items
                </span>
              </div>

              <div class="mt-5 space-y-3">
                <%= if Enum.empty?(@meal_items) do %>
                  <div class="rounded-2xl border border-dashed border-base-300 bg-base-50/70 p-8 text-center text-sm text-base-content/70">
                    Add foods from the library to build this meal.
                  </div>
                <% else %>
                  <div
                    :for={{item, index} <- Enum.with_index(@meal_items)}
                    id={"meal-item-#{index}"}
                    class="grid gap-3 rounded-2xl border border-base-200 bg-base-50 p-4 md:grid-cols-[minmax(0,1fr)_auto]"
                  >
                    <div>
                      <div class="flex items-start justify-between gap-3">
                        <div>
                          <p class="font-semibold text-base-content">{item.food_name}</p>
                          <p class="mt-1 text-sm text-base-content/60">
                            {format_decimal(item.quantity)} {item.unit}
                          </p>
                        </div>
                        <button
                          type="button"
                          phx-click="remove_item"
                          phx-value-id={index}
                          class="inline-flex h-9 w-9 items-center justify-center rounded-full border border-rose-200 text-rose-500 transition hover:bg-rose-50"
                        >
                          <.icon name="hero-trash" class="h-4 w-4" />
                        </button>
                      </div>
                      <div class="mt-3 grid gap-2 text-sm text-base-content/70 sm:grid-cols-4">
                        <p>
                          <span class="font-semibold text-base-content">Cal</span> {format_decimal(
                            item.calories
                          )}
                        </p>
                        <p>
                          <span class="font-semibold text-base-content">P</span> {format_decimal(
                            item.protein_g
                          )}g
                        </p>
                        <p>
                          <span class="font-semibold text-base-content">C</span> {format_decimal(
                            item.carbs_g
                          )}g
                        </p>
                        <p>
                          <span class="font-semibold text-base-content">F</span> {format_decimal(
                            item.fats_g
                          )}g
                        </p>
                      </div>
                    </div>
                  </div>
                <% end %>
              </div>
            </div>
          </section>

          <aside class="space-y-6">
            <div class="rounded-[2rem] border border-base-200 bg-base-100 p-6 shadow-sm">
              <div>
                <p class="text-xs uppercase tracking-[0.2em] text-base-content/50">Food picker</p>
                <h2 class="mt-2 text-xl font-semibold text-base-content">Add from your library</h2>
                <p class="mt-1 text-sm text-base-content/70">
                  Choose a saved food, set the quantity, and append it to this meal.
                </p>
              </div>

              <.form
                for={@food_picker_form}
                id="food-picker-form"
                phx-change="update_food_picker"
                class="mt-5 space-y-4"
              >
                <.input
                  field={@food_picker_form[:food_id]}
                  type="select"
                  label="Food"
                  options={@food_options}
                  prompt="Select a food"
                />
                <div class="grid gap-4 sm:grid-cols-2">
                  <.input
                    field={@food_picker_form[:quantity]}
                    type="number"
                    step="0.1"
                    min="0.1"
                    label="Quantity"
                  />
                  <.input field={@food_picker_form[:unit]} type="text" label="Unit" />
                </div>
              </.form>

              <div class="mt-5 flex flex-wrap gap-3">
                <button
                  type="button"
                  phx-click="add_food_item"
                  class="inline-flex items-center justify-center rounded-full bg-primary px-5 py-2.5 text-sm font-semibold text-white shadow-sm transition hover:-translate-y-0.5 hover:bg-primary/90"
                >
                  <.icon name="hero-plus" class="mr-2 h-4 w-4" /> Add item
                </button>
                <.link
                  navigate={~p"/foods/new"}
                  class="inline-flex items-center justify-center rounded-full border border-base-300 px-4 py-2.5 text-sm font-semibold text-base-content transition hover:border-primary hover:text-primary"
                >
                  Create food
                </.link>
              </div>
            </div>

            <div class="rounded-[2rem] border border-base-200 bg-base-100 p-6 shadow-sm">
              <div>
                <p class="text-xs uppercase tracking-[0.2em] text-base-content/50">
                  Dining URL import
                </p>
                <h2 class="mt-2 text-xl font-semibold text-base-content">Import from a menu page</h2>
                <p class="mt-1 text-sm text-base-content/70">
                  Paste a supported dining-site item URL to preload its nutrition, then fine-tune it before saving.
                </p>
                <p class="mt-3 text-xs text-base-content/55">
                  Supported right now: {Enum.join(Nutrition.supported_url_import_hosts(), ", ")}
                </p>
              </div>

              <.form
                for={@url_import_form}
                id="url-import-form"
                phx-change="update_url_import"
                phx-submit="import_url"
                class="mt-5 space-y-4"
              >
                <.input
                  field={@url_import_form[:url]}
                  type="url"
                  label="Dining item URL"
                  placeholder="https://www.mcdonalds.com/us/en-us/product/..."
                />

                <button
                  type="submit"
                  phx-disable-with="Importing..."
                  class="inline-flex items-center justify-center rounded-full bg-secondary px-5 py-2.5 text-sm font-semibold text-white shadow-sm transition hover:-translate-y-0.5 hover:bg-secondary/90"
                >
                  <.icon name="hero-link" class="mr-2 h-4 w-4" /> Import URL
                </button>
              </.form>
            </div>

            <div class="rounded-[2rem] border border-base-200 bg-base-100 p-6 shadow-sm">
              <div>
                <p class="text-xs uppercase tracking-[0.2em] text-base-content/50">
                  Screenshot import
                </p>
                <h2 class="mt-2 text-xl font-semibold text-base-content">
                  Import from screenshot
                </h2>
                <p class="mt-1 text-sm text-base-content/70">
                  Upload or paste a nutrition screenshot and Fittrack will extract the label into the review form below.
                </p>
                <p class="mt-3 text-xs text-base-content/55">
                  Supports packaged labels and dining hall nutrition modal screenshots.
                </p>
              </div>

              <div
                id="screenshot-import-panel"
                phx-hook="ScreenshotImport"
                phx-update="ignore"
                data-enabled={to_string(@screenshot_import_available?)}
                data-disabled-message="Screenshot import needs OPENAI_API_KEY before it can parse images."
                class={[
                  "mt-5 rounded-[1.5rem] border bg-[linear-gradient(145deg,rgba(255,255,255,0.95),rgba(244,248,252,0.95))] p-4",
                  if(@screenshot_import_available?,
                    do: "border-base-200",
                    else:
                      "border-amber-200 bg-[linear-gradient(145deg,rgba(255,251,235,0.95),rgba(255,247,237,0.95))]"
                  )
                ]}
              >
                <div class="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
                  <div>
                    <p class="text-xs uppercase tracking-[0.18em] text-base-content/45">
                      Image parser
                    </p>
                    <p class="mt-1 text-sm text-base-content/75">
                      Works best with screenshots of nutrition modals or labels where values are already laid out in rows.
                    </p>
                    <p data-screenshot-status class="mt-2 text-xs font-medium text-base-content/55">
                      {if @screenshot_import_available? do
                        "Upload a screenshot or paste one from your clipboard."
                      else
                        "Set OPENAI_API_KEY and reload the app to enable screenshot parsing."
                      end}
                    </p>
                  </div>

                  <div class="flex flex-wrap gap-3">
                    <input data-screenshot-input type="file" accept="image/*" class="hidden" />
                    <button
                      data-open-screenshot
                      type="button"
                      disabled={!@screenshot_import_available?}
                      class={[
                        "inline-flex items-center justify-center rounded-full px-4 py-2.5 text-sm font-semibold shadow-sm transition",
                        if(@screenshot_import_available?,
                          do: "bg-base-900 text-white hover:-translate-y-0.5 hover:bg-base-content",
                          else: "cursor-not-allowed bg-base-300 text-base-content/55"
                        )
                      ]}
                    >
                      <.icon name="hero-arrow-up-tray" class="mr-2 h-4 w-4" /> Upload screenshot
                    </button>
                  </div>
                </div>
              </div>
            </div>

            <div class="rounded-[2rem] border border-base-200 bg-base-100 p-6 shadow-sm">
              <div>
                <p class="text-xs uppercase tracking-[0.2em] text-base-content/50">Barcode import</p>
                <h2 class="mt-2 text-xl font-semibold text-base-content">Scan and confirm</h2>
                <p class="mt-1 text-sm text-base-content/70">
                  Paste a barcode, review the imported nutrition values, then add the item to this meal or save it to your library.
                </p>
              </div>

              <div
                id="barcode-import-panel"
                phx-hook="BarcodeImport"
                phx-update="ignore"
                class="mt-5 rounded-[1.5rem] border border-base-200 bg-[linear-gradient(145deg,rgba(255,255,255,0.95),rgba(245,247,250,0.95))] p-4"
              >
                <div class="flex flex-col gap-4 md:flex-row md:items-center md:justify-between">
                  <div>
                    <p class="text-xs uppercase tracking-[0.18em] text-base-content/45">
                      Camera / scanner
                    </p>
                    <p class="mt-1 text-sm text-base-content/75">
                      On mobile this opens the rear camera. On desktop it falls back to selecting an image with a visible barcode.
                    </p>
                    <p data-barcode-status class="mt-2 text-xs font-medium text-base-content/55">
                      Checking browser scanner support…
                    </p>
                  </div>

                  <div class="flex flex-wrap gap-3">
                    <input
                      id="barcode-camera-input"
                      data-barcode-input
                      type="file"
                      accept="image/*"
                      capture="environment"
                      class="hidden"
                    />
                    <button
                      id="barcode-camera-button"
                      data-open-camera
                      type="button"
                      class="inline-flex items-center justify-center rounded-full bg-base-900 px-4 py-2.5 text-sm font-semibold text-white shadow-sm transition hover:-translate-y-0.5 hover:bg-base-content"
                    >
                      <.icon name="hero-camera" class="mr-2 h-4 w-4" /> Scan with camera
                    </button>
                    <button
                      data-open-file
                      type="button"
                      class="inline-flex items-center justify-center rounded-full border border-base-300 px-4 py-2.5 text-sm font-semibold text-base-content transition hover:border-primary hover:text-primary"
                    >
                      <.icon name="hero-photo" class="mr-2 h-4 w-4" /> Use photo
                    </button>
                  </div>
                </div>
              </div>

              <.form
                for={@barcode_lookup_form}
                id="barcode-lookup-form"
                phx-change="update_barcode_lookup"
                phx-submit="lookup_barcode"
                class="mt-5 space-y-4"
              >
                <.input
                  field={@barcode_lookup_form[:barcode]}
                  type="text"
                  label="Barcode"
                  placeholder="Enter EAN / UPC"
                />

                <button
                  type="submit"
                  phx-disable-with="Looking up..."
                  class="inline-flex items-center justify-center rounded-full bg-base-900 px-5 py-2.5 text-sm font-semibold text-white shadow-sm transition hover:-translate-y-0.5 hover:bg-base-content"
                >
                  <.icon name="hero-magnifying-glass" class="mr-2 h-4 w-4" /> Import barcode
                </button>
              </.form>

              <%= if @barcode_food do %>
                <div class="mt-6 rounded-[1.75rem] border border-emerald-200 bg-[linear-gradient(160deg,rgba(236,253,245,0.95),rgba(255,255,255,0.98))] p-4 shadow-sm shadow-emerald-100/70">
                  <div class="flex items-start justify-between gap-3">
                    <div>
                      <p class="text-xs uppercase tracking-[0.18em] text-emerald-700/70">
                        Manual confirmation
                      </p>
                      <h3 class="mt-1 text-lg font-semibold text-base-content">
                        Imported product ready to review
                      </h3>
                      <p class="mt-1 text-sm text-base-content/70">
                        {@import_source_label} imported. {@import_source_detail} Adjust anything before saving.
                      </p>
                      <%= if import_context_label(@barcode_food) do %>
                        <p class="mt-2 inline-flex rounded-full border border-emerald-200 bg-emerald-50 px-3 py-1 text-xs font-semibold uppercase tracking-[0.16em] text-emerald-700">
                          {import_context_label(@barcode_food)}
                        </p>
                      <% end %>
                    </div>
                    <button
                      type="button"
                      phx-click="clear_barcode_food"
                      class="inline-flex h-9 w-9 items-center justify-center rounded-full border border-base-300 text-base-content/60 transition hover:border-base-content/30 hover:text-base-content"
                    >
                      <.icon name="hero-x-mark" class="h-4 w-4" />
                    </button>
                  </div>

                  <div class="mt-5 grid gap-3 sm:grid-cols-2">
                    <div class="rounded-2xl border border-white/80 bg-white/90 p-4 shadow-sm">
                      <p class="text-xs uppercase tracking-[0.18em] text-base-content/45">
                        Nutrition basis
                      </p>
                      <p class="mt-2 text-lg font-semibold text-base-content">
                        {format_decimal(@barcode_food["unit_amount"])} {@barcode_food["unit"]}
                      </p>
                      <p class="mt-1 text-sm text-base-content/65">
                        Imported values are currently normalized to this basis.
                      </p>
                    </div>
                    <div class="rounded-2xl border border-white/80 bg-white/90 p-4 shadow-sm">
                      <p class="text-xs uppercase tracking-[0.18em] text-base-content/45">
                        This meal entry adds
                      </p>
                      <p class="mt-2 text-lg font-semibold text-base-content">
                        {format_decimal(barcode_preview(@barcode_food).calories)} cal
                      </p>
                      <p class="mt-1 text-sm text-base-content/65">
                        {format_decimal(barcode_preview(@barcode_food).protein_g)}P / {format_decimal(
                          barcode_preview(@barcode_food).carbs_g
                        )}C / {format_decimal(barcode_preview(@barcode_food).fats_g)}F
                      </p>
                    </div>
                  </div>

                  <div class="mt-4 grid gap-3 sm:grid-cols-4">
                    <div class="rounded-2xl bg-white/90 px-4 py-3 shadow-sm">
                      <p class="text-xs uppercase tracking-[0.18em] text-orange-700">Calories</p>
                      <p class="mt-1 text-xl font-semibold text-orange-950">
                        {format_decimal(@barcode_food["calories_per_unit"])}
                      </p>
                    </div>
                    <div class="rounded-2xl bg-white/90 px-4 py-3 shadow-sm">
                      <p class="text-xs uppercase tracking-[0.18em] text-sky-700">Protein</p>
                      <p class="mt-1 text-xl font-semibold text-sky-950">
                        {format_decimal(@barcode_food["protein_per_unit"])}g
                      </p>
                    </div>
                    <div class="rounded-2xl bg-white/90 px-4 py-3 shadow-sm">
                      <p class="text-xs uppercase tracking-[0.18em] text-emerald-700">Carbs</p>
                      <p class="mt-1 text-xl font-semibold text-emerald-950">
                        {format_decimal(@barcode_food["carbs_per_unit"])}g
                      </p>
                    </div>
                    <div class="rounded-2xl bg-white/90 px-4 py-3 shadow-sm">
                      <p class="text-xs uppercase tracking-[0.18em] text-amber-700">Fats</p>
                      <p class="mt-1 text-xl font-semibold text-amber-950">
                        {format_decimal(@barcode_food["fats_per_unit"])}g
                      </p>
                    </div>
                  </div>

                  <%= if import_source_metadata_present?(@barcode_food) do %>
                    <div class="mt-4 rounded-2xl border border-white/80 bg-white/90 p-4 shadow-sm">
                      <p class="text-xs uppercase tracking-[0.18em] text-base-content/45">
                        Source image
                      </p>
                      <p class="mt-2 text-sm font-medium text-base-content">
                        {format_source_image_metadata(@barcode_food)}
                      </p>
                    </div>
                  <% end %>

                  <%= if import_text_lines(@barcode_food) != [] or import_field_mapping(@barcode_food) != [] do %>
                    <div class="mt-4 grid gap-4 lg:grid-cols-2">
                      <%= if import_text_lines(@barcode_food) != [] do %>
                        <div class="rounded-2xl border border-white/80 bg-white/90 p-4 shadow-sm">
                          <p class="text-xs uppercase tracking-[0.18em] text-base-content/45">
                            Extracted text
                          </p>
                          <div class="mt-3 space-y-2 text-sm text-base-content/75">
                            <p
                              :for={line <- import_text_lines(@barcode_food)}
                              class="rounded-xl bg-base-50 px-3 py-2"
                            >
                              {line}
                            </p>
                          </div>
                        </div>
                      <% end %>

                      <%= if import_field_mapping(@barcode_food) != [] do %>
                        <div class="rounded-2xl border border-white/80 bg-white/90 p-4 shadow-sm">
                          <p class="text-xs uppercase tracking-[0.18em] text-base-content/45">
                            Field mapping
                          </p>
                          <div class="mt-3 space-y-2 text-sm text-base-content/75">
                            <div
                              :for={{field, value} <- import_field_mapping(@barcode_food)}
                              class="flex items-start justify-between gap-3 rounded-xl bg-base-50 px-3 py-2"
                            >
                              <span class="font-semibold text-base-content">{field}</span>
                              <span class="text-right">{value}</span>
                            </div>
                          </div>
                        </div>
                      <% end %>
                    </div>
                  <% end %>

                  <.form
                    for={@barcode_food_form}
                    id="barcode-confirmation-form"
                    phx-change="update_barcode_food"
                    class="mt-5 space-y-4"
                  >
                    <div class="grid gap-4">
                      <.input
                        field={@barcode_food_form[:name]}
                        type="text"
                        label="Food name"
                        required
                      />
                      <div class="grid gap-4 sm:grid-cols-2">
                        <.input
                          field={@barcode_food_form[:unit]}
                          type="text"
                          label="Unit"
                          required
                        />
                        <.input
                          field={@barcode_food_form[:unit_amount]}
                          type="number"
                          step="0.1"
                          min="0.1"
                          label="Nutrition basis"
                          required
                        />
                      </div>
                      <.input
                        field={@barcode_food_form[:quantity]}
                        type="number"
                        step="0.1"
                        min="0.1"
                        label="Meal quantity"
                        required
                      />
                      <div class="grid gap-4 sm:grid-cols-2">
                        <.input
                          field={@barcode_food_form[:calories_per_unit]}
                          type="number"
                          step="0.1"
                          min="0"
                          label="Calories"
                          required
                        />
                        <.input
                          field={@barcode_food_form[:protein_per_unit]}
                          type="number"
                          step="0.1"
                          min="0"
                          label="Protein (g)"
                        />
                        <.input
                          field={@barcode_food_form[:carbs_per_unit]}
                          type="number"
                          step="0.1"
                          min="0"
                          label="Carbs (g)"
                        />
                        <.input
                          field={@barcode_food_form[:fats_per_unit]}
                          type="number"
                          step="0.1"
                          min="0"
                          label="Fats (g)"
                        />
                        <.input
                          field={@barcode_food_form[:fiber_per_unit]}
                          type="number"
                          step="0.1"
                          min="0"
                          label="Fiber (g)"
                        />
                        <.input
                          field={@barcode_food_form[:sugar_per_unit]}
                          type="number"
                          step="0.1"
                          min="0"
                          label="Sugar (g)"
                        />
                        <.input
                          field={@barcode_food_form[:sodium_mg_per_unit]}
                          type="number"
                          step="0.1"
                          min="0"
                          label="Sodium (mg)"
                        />
                      </div>
                      <div>
                        <.input
                          field={@barcode_food_form[:micronutrients_text]}
                          type="textarea"
                          label="Other nutrients"
                          placeholder="Vitamin C: 20 mg&#10;Potassium: 470 mg"
                        />
                      </div>
                    </div>
                  </.form>

                  <div class="mt-5 flex flex-wrap gap-3">
                    <button
                      type="button"
                      phx-click="add_barcode_item"
                      class="inline-flex items-center justify-center rounded-full bg-primary px-5 py-2.5 text-sm font-semibold text-white shadow-sm transition hover:-translate-y-0.5 hover:bg-primary/90"
                    >
                      <.icon name="hero-plus" class="mr-2 h-4 w-4" /> Save to meal
                    </button>
                    <button
                      type="button"
                      phx-click="save_barcode_food"
                      class="inline-flex items-center justify-center rounded-full border border-base-300 px-5 py-2.5 text-sm font-semibold text-base-content transition hover:border-primary hover:text-primary"
                    >
                      <.icon name="hero-bookmark" class="mr-2 h-4 w-4" /> Save to library
                    </button>
                  </div>
                </div>
              <% else %>
                <div class="mt-6 rounded-[1.5rem] border border-dashed border-base-300 bg-base-50/70 p-5">
                  <div class="flex items-start gap-4">
                    <div class="rounded-2xl bg-white p-3 shadow-sm">
                      <.icon name="hero-qr-code" class="h-6 w-6 text-base-content/70" />
                    </div>
                    <div>
                      <h3 class="text-sm font-semibold text-base-content">No imported item yet</h3>
                      <p class="mt-1 text-sm leading-6 text-base-content/70">
                        Import from a barcode, dining URL, or screenshot to preload nutrition values, then confirm the serving basis and meal quantity before saving.
                      </p>
                    </div>
                  </div>
                </div>
              <% end %>
            </div>

            <div class="rounded-[2rem] border border-base-200 bg-base-100 p-6 shadow-sm">
              <p class="text-xs uppercase tracking-[0.2em] text-base-content/50">Totals</p>
              <h2 class="mt-2 text-xl font-semibold text-base-content">Macro snapshot</h2>

              <div class="mt-5 grid gap-3 sm:grid-cols-2">
                <div class="rounded-2xl bg-orange-50 p-4">
                  <p class="text-sm text-orange-700">Calories</p>
                  <p class="mt-1 text-2xl font-semibold text-orange-950">
                    {format_decimal(@total_calories)}
                  </p>
                </div>
                <div class="rounded-2xl bg-sky-50 p-4">
                  <p class="text-sm text-sky-700">Protein</p>
                  <p class="mt-1 text-2xl font-semibold text-sky-950">
                    {format_decimal(@total_protein_g)}g
                  </p>
                </div>
                <div class="rounded-2xl bg-emerald-50 p-4">
                  <p class="text-sm text-emerald-700">Carbs</p>
                  <p class="mt-1 text-2xl font-semibold text-emerald-950">
                    {format_decimal(@total_carbs_g)}g
                  </p>
                </div>
                <div class="rounded-2xl bg-amber-50 p-4">
                  <p class="text-sm text-amber-700">Fats</p>
                  <p class="mt-1 text-2xl font-semibold text-amber-950">
                    {format_decimal(@total_fats_g)}g
                  </p>
                </div>
              </div>
            </div>
          </aside>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    current_scope = socket.assigns.current_scope
    foods = Nutrition.list_foods(current_scope)

    {:ok,
     socket
     |> assign(:return_to, "index")
     |> assign(:foods, foods)
     |> assign(:food_options, food_options(foods))
     |> assign(:meal_items, [])
     |> assign(:selected_food_id, nil)
     |> assign(:total_calories, Decimal.new(0))
     |> assign(:total_protein_g, Decimal.new(0))
     |> assign(:total_carbs_g, Decimal.new(0))
     |> assign(:total_fats_g, Decimal.new(0))
     |> assign(:import_source_label, "Item")
     |> assign(:import_source_detail, "")
     |> assign(:screenshot_import_available?, Nutrition.screenshot_import_available?())
     |> assign_food_picker(%{"food_id" => "", "quantity" => "100", "unit" => "g"})
     |> assign_url_import(%{"url" => ""})
     |> assign_barcode_lookup(%{"barcode" => ""})
     |> clear_barcode_food()}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    meal = Nutrition.get_meal!(socket.assigns.current_scope, id)

    meal_items =
      Enum.map(meal.meal_items, fn item ->
        %{
          id: item.id,
          food_name: item.food_name,
          quantity: item.quantity,
          unit: item.unit,
          calories: item.calories,
          protein_g: item.protein_g,
          carbs_g: item.carbs_g,
          fats_g: item.fats_g,
          fiber_g: item.fiber_g,
          sugar_g: item.sugar_g,
          sodium_mg: item.sodium_mg,
          micronutrients: item.micronutrients,
          food_id: item.food_id
        }
      end)

    totals = Nutrition.calculate_meal_totals(meal_items)

    socket
    |> assign(:page_title, "Edit meal")
    |> assign(:meal, meal)
    |> assign(:form, to_form(Nutrition.change_meal(meal)))
    |> assign(:meal_items, meal_items)
    |> assign(:total_calories, totals.total_calories)
    |> assign(:total_protein_g, totals.total_protein_g)
    |> assign(:total_carbs_g, totals.total_carbs_g)
    |> assign(:total_fats_g, totals.total_fats_g)
  end

  defp apply_action(socket, :new, _params) do
    meal = %Meal{eaten_at: DateTime.utc_now()}

    socket
    |> assign(:page_title, "Log a meal")
    |> assign(:meal, meal)
    |> assign(:form, to_form(Nutrition.change_meal(meal)))
  end

  @impl true
  def handle_event("validate", %{"meal" => meal_params}, socket) do
    changeset = Nutrition.change_meal(socket.assigns.meal, meal_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("update_food_picker", %{"food_picker" => params}, socket) do
    unit =
      case params["food_id"] do
        "" ->
          params["unit"]

        nil ->
          params["unit"]

        food_id ->
          case Nutrition.get_food(socket.assigns.current_scope, food_id) do
            nil -> params["unit"]
            food -> food.unit
          end
      end

    {:noreply, assign_food_picker(socket, Map.put(params, "unit", unit))}
  end

  def handle_event("update_barcode_lookup", %{"barcode_lookup" => params}, socket) do
    {:noreply, assign_barcode_lookup(socket, params)}
  end

  def handle_event("update_url_import", %{"url_import" => params}, socket) do
    {:noreply, assign_url_import(socket, params)}
  end

  def handle_event("import_url", %{"url_import" => %{"url" => url}}, socket) do
    {:noreply, perform_url_import(socket, url)}
  end

  def handle_event("lookup_barcode", %{"barcode_lookup" => %{"barcode" => barcode}}, socket) do
    {:noreply, perform_barcode_lookup(socket, barcode)}
  end

  def handle_event("barcode_detected", %{"barcode" => barcode}, socket) do
    {:noreply, perform_barcode_lookup(socket, barcode)}
  end

  def handle_event("barcode_scan_error", %{"message" => message}, socket) do
    {:noreply, put_flash(socket, :error, message)}
  end

  def handle_event("screenshot_selected", %{"data_url" => data_url} = params, socket) do
    {:noreply,
     perform_screenshot_import(socket, data_url, params["source_image_metadata"] || %{})}
  end

  def handle_event("screenshot_import_error", %{"message" => message}, socket) do
    {:noreply, put_flash(socket, :error, message)}
  end

  def handle_event("update_barcode_food", %{"barcode_food" => params}, socket) do
    {:noreply, assign_barcode_food(socket, params)}
  end

  def handle_event("clear_barcode_food", _params, socket) do
    {:noreply, clear_barcode_food(socket)}
  end

  def handle_event("add_food_item", _params, socket) do
    picker = socket.assigns.food_picker
    food_id = picker["food_id"]
    quantity = picker["quantity"]

    with food_id when food_id not in [nil, ""] <- food_id,
         %Fittrack.Nutrition.Food{} = food <-
           Nutrition.get_food(socket.assigns.current_scope, food_id),
         item when not is_nil(item) <-
           Nutrition.build_meal_item_from_food(socket.assigns.current_scope, food_id, quantity) do
      meal_items =
        socket.assigns.meal_items ++ [Map.put(item, :unit, picker["unit"] || food.unit)]

      {:noreply,
       socket
       |> assign_meal_totals(meal_items)
       |> assign_food_picker(%{"food_id" => food_id, "quantity" => "100", "unit" => food.unit})}
    else
      _ ->
        {:noreply,
         put_flash(socket, :error, "Select a valid food and quantity before adding it.")}
    end
  end

  def handle_event("add_barcode_item", _params, socket) do
    case Nutrition.build_meal_item(socket.assigns.barcode_food || %{}) do
      %{} = item ->
        {:noreply,
         socket
         |> assign_meal_totals(socket.assigns.meal_items ++ [item])
         |> put_flash(:info, "Imported item added to this meal.")
         |> clear_barcode_food()}

      _ ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Confirm a valid quantity, nutrition basis, and food name before saving to the meal."
         )}
    end
  end

  def handle_event("save_barcode_food", _params, socket) do
    attrs = barcode_food_library_attrs(socket.assigns.barcode_food || %{})

    case Nutrition.create_food(socket.assigns.current_scope, attrs) do
      {:ok, food} ->
        foods = Nutrition.list_foods(socket.assigns.current_scope)

        {:noreply,
         socket
         |> assign(:foods, foods)
         |> assign(:food_options, food_options(foods))
         |> assign_food_picker(%{
           "food_id" => to_string(food.id),
           "quantity" => format_decimal(food.unit_amount),
           "unit" => food.unit
         })
         |> clear_barcode_food()
         |> put_flash(:info, "Imported food saved to your library.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        first_error =
          changeset.errors
          |> Enum.map(fn {field, {message, _opts}} -> "#{field} #{message}" end)
          |> List.first()

        {:noreply,
         put_flash(
           socket,
           :error,
           first_error || "Review the imported values before saving to your library."
         )}
    end
  end

  def handle_event("remove_item", %{"id" => index}, socket) do
    meal_items = List.delete_at(socket.assigns.meal_items, String.to_integer(index))
    {:noreply, assign_meal_totals(socket, meal_items)}
  end

  def handle_event("save", %{"meal" => meal_params}, socket) do
    meal_attrs = Map.put(meal_params, "meal_items", socket.assigns.meal_items)
    save_meal(socket, socket.assigns.live_action, meal_attrs)
  end

  defp save_meal(socket, :edit, meal_params) do
    case Nutrition.update_meal(socket.assigns.current_scope, socket.assigns.meal, meal_params) do
      {:ok, meal} ->
        {:noreply,
         socket
         |> put_flash(:info, "Meal updated successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, meal))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, action: :update))}
    end
  end

  defp save_meal(socket, :new, meal_params) do
    case Nutrition.create_meal(socket.assigns.current_scope, meal_params) do
      {:ok, meal} ->
        {:noreply,
         socket
         |> put_flash(:info, "Meal logged successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, meal))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, action: :insert))}
    end
  end

  defp food_options(foods) do
    Enum.map(foods, fn food ->
      {"#{food.name} (#{format_decimal(food.unit_amount)} #{food.unit})", food.id}
    end)
  end

  defp assign_food_picker(socket, picker) do
    socket
    |> assign(:food_picker, picker)
    |> assign(:food_picker_form, to_form(picker, as: :food_picker))
  end

  defp assign_barcode_lookup(socket, params) do
    socket
    |> assign(:barcode_lookup, params)
    |> assign(:barcode_lookup_form, to_form(params, as: :barcode_lookup))
  end

  defp assign_url_import(socket, params) do
    socket
    |> assign(:url_import, params)
    |> assign(:url_import_form, to_form(params, as: :url_import))
  end

  defp assign_barcode_food(socket, params) do
    merged_params =
      socket.assigns[:barcode_food]
      |> Nutrition.normalize_metadata_map()
      |> Map.merge(params)

    socket
    |> assign(:barcode_food, merged_params)
    |> assign(:barcode_food_form, to_form(merged_params, as: :barcode_food))
  end

  defp clear_barcode_food(socket) do
    socket
    |> assign(:import_source_label, "Item")
    |> assign(:import_source_detail, "")
    |> assign(:barcode_food, nil)
    |> assign(
      :barcode_food_form,
      to_form(Nutrition.barcode_food_defaults(%{}), as: :barcode_food)
    )
  end

  defp perform_barcode_lookup(socket, barcode) do
    socket = assign_barcode_lookup(socket, %{"barcode" => barcode})

    case Nutrition.lookup_food_by_barcode(barcode) do
      {:ok, attrs} ->
        socket
        |> assign(:import_source_label, "Barcode")
        |> assign(:import_source_detail, "#{barcode}.")
        |> assign_barcode_food(Nutrition.barcode_food_defaults(attrs))
        |> put_flash(:info, "Barcode imported. Confirm the values before saving.")

      {:error, :blank_barcode} ->
        put_flash(socket, :error, "Enter a barcode before importing.")

      {:error, :invalid_barcode} ->
        put_flash(socket, :error, "Use digits only for barcode imports.")

      {:error, :not_found} ->
        put_flash(socket, :error, "No product was found for that barcode.")

      {:error, :lookup_failed} ->
        put_flash(socket, :error, "Barcode lookup failed. Try again in a moment.")
    end
  end

  defp perform_url_import(socket, url) do
    socket = assign_url_import(socket, %{"url" => url})

    case Nutrition.import_food_from_url(url) do
      {:ok, attrs} ->
        host =
          case URI.parse(url) do
            %URI{host: host} when is_binary(host) -> host
            _ -> "URL"
          end

        socket
        |> assign(:import_source_label, "Dining URL")
        |> assign(:import_source_detail, "#{host}.")
        |> assign_barcode_food(Nutrition.barcode_food_defaults(attrs))
        |> put_flash(:info, "Dining URL imported. Review and correct anything before saving.")

      {:error, :invalid_url} ->
        put_flash(socket, :error, "Enter a valid http or https dining URL.")

      {:error, :unsupported_host} ->
        put_flash(
          socket,
          :error,
          "That site is not supported yet. Use one of the listed dining hosts or correct it manually."
        )

      {:error, :nutrition_not_found} ->
        put_flash(
          socket,
          :error,
          "We could load the page but could not parse nutrition from it. Try another item URL."
        )

      {:error, :fetch_failed} ->
        put_flash(socket, :error, "The dining page could not be loaded right now.")
    end
  end

  defp perform_screenshot_import(socket, data_url, source_image_metadata) do
    case Nutrition.import_food_from_screenshot(data_url, source_image_metadata) do
      {:ok, attrs} ->
        socket
        |> assign(:import_source_label, "Screenshot")
        |> assign(:import_source_detail, screenshot_import_detail(attrs))
        |> assign_barcode_food(attrs)
        |> put_flash(:info, "Screenshot imported. Review and correct anything before saving.")

      {:error, :invalid_image} ->
        put_flash(socket, :error, "Choose or paste a valid screenshot image.")

      {:error, :not_configured} ->
        put_flash(
          socket,
          :error,
          "Screenshot import needs OPENAI_API_KEY. Set it in your environment and reload the app."
        )

      {:error, :parse_failed} ->
        put_flash(
          socket,
          :error,
          "The screenshot could not be parsed cleanly. Try a clearer image or enter it manually."
        )
    end
  end

  defp barcode_food_library_attrs(attrs) do
    Map.take(attrs, [
      "name",
      "unit",
      "unit_amount",
      "calories_per_unit",
      "protein_per_unit",
      "carbs_per_unit",
      "fats_per_unit",
      "fiber_per_unit",
      "sugar_per_unit",
      "sodium_mg_per_unit",
      "source_image_metadata",
      "parsed_values"
    ])
    |> Map.put("micronutrients", Nutrition.parse_micronutrients(attrs["micronutrients_text"]))
  end

  defp screenshot_import_detail(attrs) do
    parsed_values = Nutrition.normalize_metadata_map(attrs["parsed_values"])
    detected_context = Nutrition.normalize_metadata_map(parsed_values["detected_context"])
    venue_name = parsed_values["venue_name"]

    cond do
      venue_name not in [nil, ""] ->
        "#{venue_name} screenshot."

      detected_context["kind"] == "dining_hall_modal" ->
        "dining hall modal screenshot."

      true ->
        "image import."
    end
  end

  defp import_context_label(nil), do: nil

  defp import_context_label(attrs) do
    parsed_values = Nutrition.normalize_metadata_map(attrs["parsed_values"])
    detected_context = Nutrition.normalize_metadata_map(parsed_values["detected_context"])

    case detected_context["kind"] do
      "dining_hall_modal" ->
        "Dining hall modal"

      "nutrition_label" ->
        "Nutrition label"

      value when is_binary(value) and value != "" ->
        value |> String.replace("_", " ") |> String.capitalize()

      _ ->
        nil
    end
  end

  defp import_source_metadata_present?(attrs) do
    metadata = Nutrition.normalize_metadata_map(attrs["source_image_metadata"])
    map_size(metadata) > 0
  end

  defp format_source_image_metadata(attrs) do
    metadata = Nutrition.normalize_metadata_map(attrs["source_image_metadata"])

    parts =
      [
        metadata["filename"],
        metadata["source"],
        metadata["mime_type"],
        format_byte_size(metadata["byte_size"]),
        format_dimensions(metadata["width"], metadata["height"])
      ]
      |> Enum.filter(&(&1 not in [nil, ""]))

    Enum.join(parts, " • ")
  end

  defp import_text_lines(nil), do: []

  defp import_text_lines(attrs) do
    attrs["parsed_values"]
    |> Nutrition.normalize_metadata_map()
    |> Map.get("extracted_text", [])
    |> case do
      values when is_list(values) -> values
      _ -> []
    end
  end

  defp import_field_mapping(nil), do: []

  defp import_field_mapping(attrs) do
    attrs["parsed_values"]
    |> Nutrition.normalize_metadata_map()
    |> Map.get("field_mapping", %{})
    |> Nutrition.normalize_metadata_map()
    |> Enum.map(fn {field, value} -> {humanize_import_field(field), value} end)
    |> Enum.sort_by(fn {field, _value} -> field end)
  end

  defp humanize_import_field(field) do
    field
    |> String.replace("_per_unit", "")
    |> String.replace("_mg", " mg")
    |> String.replace("_g", " g")
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  defp format_byte_size(nil), do: nil
  defp format_byte_size(size) when is_binary(size), do: format_byte_size(String.to_integer(size))

  defp format_byte_size(size) when is_integer(size) and size >= 1024 do
    "#{Float.round(size / 1024, 1)} KB"
  end

  defp format_byte_size(size) when is_integer(size) and size > 0, do: "#{size} B"
  defp format_byte_size(_), do: nil

  defp format_dimensions(width, height)
       when is_integer(width) and width > 0 and is_integer(height) and height > 0 do
    "#{width}x#{height}"
  end

  defp format_dimensions(_, _), do: nil

  defp assign_meal_totals(socket, meal_items) do
    totals = Nutrition.calculate_meal_totals(meal_items)

    socket
    |> assign(:meal_items, meal_items)
    |> assign(:total_calories, totals.total_calories)
    |> assign(:total_protein_g, totals.total_protein_g)
    |> assign(:total_carbs_g, totals.total_carbs_g)
    |> assign(:total_fats_g, totals.total_fats_g)
  end

  defp format_decimal(nil), do: "0"
  defp format_decimal(value) when is_binary(value), do: value |> Decimal.new() |> format_decimal()

  defp format_decimal(%Decimal{} = value) do
    value
    |> Decimal.round(2)
    |> Decimal.normalize()
    |> Decimal.to_string(:normal)
  end

  defp barcode_preview(barcode_food) do
    Nutrition.build_meal_item(barcode_food) ||
      %{
        calories: Decimal.new(0),
        protein_g: Decimal.new(0),
        carbs_g: Decimal.new(0),
        fats_g: Decimal.new(0),
        fiber_g: Decimal.new(0),
        sugar_g: Decimal.new(0),
        sodium_mg: Decimal.new(0)
      }
  end

  defp return_path("index", _meal), do: ~p"/meals"
  defp return_path("show", meal), do: ~p"/meals/#{meal}"
end
