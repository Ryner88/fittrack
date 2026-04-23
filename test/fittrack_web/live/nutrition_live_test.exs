defmodule FittrackWeb.NutritionLiveTest do
  use FittrackWeb.ConnCase

  import Phoenix.LiveViewTest
  import Fittrack.AccountsFixtures
  import Fittrack.NutritionFixtures

  setup do
    original_client = Application.get_env(:fittrack, :barcode_lookup_http_client)
    original_response = Application.get_env(:fittrack, :barcode_lookup_test_response)
    original_url_client = Application.get_env(:fittrack, :url_import_http_client)
    original_url_response = Application.get_env(:fittrack, :url_import_test_response)
    original_screenshot_client = Application.get_env(:fittrack, :screenshot_import_parser_client)

    original_screenshot_response =
      Application.get_env(:fittrack, :screenshot_import_test_response)

    Application.put_env(:fittrack, :barcode_lookup_http_client, Fittrack.BarcodeLookupClientStub)
    Application.put_env(:fittrack, :url_import_http_client, Fittrack.UrlImportHttpClientStub)

    Application.put_env(
      :fittrack,
      :screenshot_import_parser_client,
      Fittrack.ScreenshotImportParserClientStub
    )

    on_exit(fn ->
      if original_client do
        Application.put_env(:fittrack, :barcode_lookup_http_client, original_client)
      else
        Application.delete_env(:fittrack, :barcode_lookup_http_client)
      end

      if original_response do
        Application.put_env(:fittrack, :barcode_lookup_test_response, original_response)
      else
        Application.delete_env(:fittrack, :barcode_lookup_test_response)
      end

      if original_url_client do
        Application.put_env(:fittrack, :url_import_http_client, original_url_client)
      else
        Application.delete_env(:fittrack, :url_import_http_client)
      end

      if original_url_response do
        Application.put_env(:fittrack, :url_import_test_response, original_url_response)
      else
        Application.delete_env(:fittrack, :url_import_test_response)
      end

      if original_screenshot_client do
        Application.put_env(
          :fittrack,
          :screenshot_import_parser_client,
          original_screenshot_client
        )
      else
        Application.delete_env(:fittrack, :screenshot_import_parser_client)
      end

      if original_screenshot_response do
        Application.put_env(
          :fittrack,
          :screenshot_import_test_response,
          original_screenshot_response
        )
      else
        Application.delete_env(:fittrack, :screenshot_import_test_response)
      end
    end)

    :ok
  end

  test "dashboard shows and lists stats", %{conn: conn} do
    user = user_fixture()
    conn = log_in_user(conn, user)

    {:ok, _view, html} = live(conn, ~p"/nutrition")
    assert html =~ "Nutrition Dashboard"
  end

  test "can create a meal via LiveView flow", %{conn: conn} do
    user = user_fixture()
    scope = %Fittrack.Accounts.Scope{user: user}
    food = food_fixture(scope)

    conn = log_in_user(conn, user)
    {:ok, view, _} = live(conn, ~p"/meals/new")

    assert has_element?(view, "#meal-form")
    assert has_element?(view, "#food-picker-form")

    view
    |> form("#food-picker-form", %{
      "food_picker" => %{
        "food_id" => to_string(food.id),
        "quantity" => "100",
        "unit" => "g"
      }
    })
    |> render_change()

    view
    |> element("button[phx-click=\"add_food_item\"]")
    |> render_click()

    eaten_at =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.truncate(:second)
      |> Calendar.strftime("%Y-%m-%dT%H:%M:%S")

    {:ok, _redirected_view, redirected_html} =
      view
      |> form("#meal-form", %{
        "meal" => %{
          "name" => "Breakfast",
          "eaten_at" => eaten_at
        }
      })
      |> render_submit()
      |> follow_redirect(conn, ~p"/meals")

    assert redirected_html =~ "Meal logged successfully"
    assert redirected_html =~ "Breakfast"
  end

  test "can import a barcode and add it to the current meal", %{conn: conn} do
    Application.put_env(:fittrack, :barcode_lookup_test_response, {
      :ok,
      %{
        status: 200,
        body: %{
          "status" => 1,
          "product" => %{
            "product_name" => "Greek Yogurt",
            "serving_size" => "150 g",
            "nutriments" => %{
              "energy-kcal_100g" => 97,
              "proteins_100g" => 10,
              "carbohydrates_100g" => 3.6,
              "fat_100g" => 5
            }
          }
        }
      }
    })

    user = user_fixture()
    conn = log_in_user(conn, user)

    {:ok, view, _html} = live(conn, ~p"/meals/new")

    view
    |> form("#barcode-lookup-form", %{"barcode_lookup" => %{"barcode" => "1234567890123"}})
    |> render_submit()

    assert has_element?(view, "#barcode-confirmation-form")
    refute has_element?(view, "#meal-item-0")

    view
    |> form("#barcode-confirmation-form", %{
      "barcode_food" => %{
        "name" => "Greek Yogurt",
        "unit" => "g",
        "unit_amount" => "100",
        "quantity" => "150",
        "calories_per_unit" => "97",
        "protein_per_unit" => "10",
        "carbs_per_unit" => "3.6",
        "fats_per_unit" => "5"
      }
    })
    |> render_change()

    view
    |> element("button[phx-click=\"add_barcode_item\"]")
    |> render_click()

    assert has_element?(view, "#meal-item-0")
    assert render(view) =~ "Greek Yogurt"
  end

  test "barcode hook event populates the confirmation panel", %{conn: conn} do
    Application.put_env(:fittrack, :barcode_lookup_test_response, {
      :ok,
      %{
        status: 200,
        body: %{
          "status" => 1,
          "product" => %{
            "product_name" => "Trail Mix",
            "serving_size" => "40 g",
            "nutriments" => %{
              "energy-kcal_100g" => 510,
              "proteins_100g" => 14,
              "carbohydrates_100g" => 42,
              "fat_100g" => 31
            }
          }
        }
      }
    })

    user = user_fixture()
    conn = log_in_user(conn, user)

    {:ok, view, _html} = live(conn, ~p"/meals/new")

    assert has_element?(view, "#barcode-camera-button")
    assert has_element?(view, "#barcode-import-panel")

    view
    |> element("#barcode-import-panel")
    |> render_hook("barcode_detected", %{"barcode" => "3213213213210"})

    assert has_element?(view, "#barcode-confirmation-form")
    assert render(view) =~ "Trail Mix"
  end

  test "can import a barcode and save it to the food library", %{conn: conn} do
    Application.put_env(:fittrack, :barcode_lookup_test_response, {
      :ok,
      %{
        status: 200,
        body: %{
          "status" => 1,
          "product" => %{
            "product_name" => "Oat Milk",
            "serving_size" => "240 ml",
            "nutriments" => %{
              "energy-kcal_serving" => 120,
              "proteins_serving" => 3,
              "carbohydrates_serving" => 16,
              "fat_serving" => 5
            }
          }
        }
      }
    })

    user = user_fixture()
    scope = %Fittrack.Accounts.Scope{user: user}
    conn = log_in_user(conn, user)

    {:ok, view, _html} = live(conn, ~p"/meals/new")

    view
    |> form("#barcode-lookup-form", %{"barcode_lookup" => %{"barcode" => "9999999999999"}})
    |> render_submit()

    view
    |> form("#barcode-confirmation-form", %{
      "barcode_food" => %{
        "name" => "Oat Milk",
        "unit" => "ml",
        "unit_amount" => "240",
        "quantity" => "240",
        "calories_per_unit" => "120",
        "protein_per_unit" => "3",
        "carbs_per_unit" => "16",
        "fats_per_unit" => "5"
      }
    })
    |> render_change()

    view
    |> element("button[phx-click=\"save_barcode_food\"]")
    |> render_click()

    assert Enum.any?(Fittrack.Nutrition.list_foods(scope), &(&1.name == "Oat Milk"))
  end

  test "can import a supported dining URL and add it to the current meal", %{conn: conn} do
    Application.put_env(:fittrack, :url_import_test_response, {
      :ok,
      %{
        status: 200,
        body: """
        <html>
          <head>
            <script type="application/ld+json">
              {
                "@context": "https://schema.org",
                "@type": "MenuItem",
                "name": "McDouble",
                "nutrition": {
                  "@type": "NutritionInformation",
                  "servingSize": "1 burger",
                  "calories": "390 calories",
                  "proteinContent": "22 g",
                  "carbohydrateContent": "33 g",
                  "fatContent": "18 g"
                }
              }
            </script>
          </head>
        </html>
        """
      }
    })

    user = user_fixture()
    conn = log_in_user(conn, user)

    {:ok, view, _html} = live(conn, ~p"/meals/new")

    view
    |> form("#url-import-form", %{
      "url_import" => %{"url" => "https://www.mcdonalds.com/us/en-us/product/mcdouble.html"}
    })
    |> render_submit()

    assert has_element?(view, "#barcode-confirmation-form")
    assert render(view) =~ "McDouble"
    assert render(view) =~ "Dining URL imported"

    view
    |> element("button[phx-click=\"add_barcode_item\"]")
    |> render_click()

    assert has_element?(view, "#meal-item-0")
    assert render(view) =~ "McDouble"
  end

  test "can import a nutrition screenshot and review extended nutrients", %{conn: conn} do
    Application.put_env(:fittrack, :screenshot_import_test_response, {
      :ok,
      %{
        "name" => "Turkey Sandwich",
        "unit" => "serving",
        "unit_amount" => "1",
        "quantity" => "1",
        "calories_per_unit" => "420",
        "protein_per_unit" => "28",
        "carbs_per_unit" => "34",
        "fats_per_unit" => "18",
        "fiber_per_unit" => "5",
        "sugar_per_unit" => "6",
        "sodium_mg_per_unit" => "870",
        "micronutrients" => %{"Potassium" => "420 mg", "Calcium" => "120 mg"},
        "extraction" => %{
          "screen_type" => "dining_hall_modal",
          "venue_name" => "North Dining Hall",
          "serving_size_text" => "1 sandwich",
          "extracted_text" => [
            "North Dining Hall",
            "Turkey Sandwich",
            "Calories 420",
            "Protein 28g"
          ],
          "field_mapping" => %{
            "calories_per_unit" => "Calories 420",
            "protein_per_unit" => "Protein 28g",
            "carbs_per_unit" => "Carbs 34g"
          }
        }
      }
    })

    user = user_fixture()
    conn = log_in_user(conn, user)

    {:ok, view, _html} = live(conn, ~p"/meals/new")

    assert has_element?(view, "#screenshot-import-panel")

    view
    |> element("#screenshot-import-panel")
    |> render_hook("screenshot_selected", %{
      "data_url" => "data:image/png;base64,abc123",
      "source_image_metadata" => %{
        "source" => "upload",
        "filename" => "turkey-sandwich.png",
        "mime_type" => "image/png",
        "byte_size" => 24_000,
        "width" => 1080,
        "height" => 1350
      }
    })

    assert has_element?(view, "#barcode-confirmation-form")
    assert render(view) =~ "Turkey Sandwich"
    assert render(view) =~ "Fiber (g)"
    assert render(view) =~ "Sodium (mg)"
    assert render(view) =~ "Potassium: 420 mg"
    assert render(view) =~ "Dining hall modal"
    assert render(view) =~ "North Dining Hall"
    assert render(view) =~ "turkey-sandwich.png"
    assert render(view) =~ "Calories 420"
    assert render(view) =~ "Protein 28g"
  end

  test "screenshot imports persist metadata when saved to the library", %{conn: conn} do
    Application.put_env(:fittrack, :screenshot_import_test_response, {
      :ok,
      %{
        "name" => "Dining Hall Chili",
        "unit" => "serving",
        "unit_amount" => "1",
        "quantity" => "1",
        "calories_per_unit" => "310",
        "protein_per_unit" => "18",
        "carbs_per_unit" => "24",
        "fats_per_unit" => "14",
        "extraction" => %{
          "screen_type" => "dining_hall_modal",
          "extracted_text" => ["Dining Hall Chili", "Calories 310"],
          "field_mapping" => %{"calories_per_unit" => "Calories 310"}
        }
      }
    })

    user = user_fixture()
    scope = %Fittrack.Accounts.Scope{user: user}
    conn = log_in_user(conn, user)

    {:ok, view, _html} = live(conn, ~p"/meals/new")

    view
    |> element("#screenshot-import-panel")
    |> render_hook("screenshot_selected", %{
      "data_url" => "data:image/png;base64,abc123",
      "source_image_metadata" => %{"source" => "clipboard", "mime_type" => "image/png"}
    })

    view
    |> element("button[phx-click=\"save_barcode_food\"]")
    |> render_click()

    food = Enum.find(Fittrack.Nutrition.list_foods(scope), &(&1.name == "Dining Hall Chili"))
    assert food.source_image_metadata["source"] == "clipboard"
    assert food.parsed_values["detected_context"]["kind"] == "dining_hall_modal"
    assert food.parsed_values["field_mapping"]["calories_per_unit"] == "Calories 310"
  end

  test "can create a meal plan via LiveView", %{conn: conn} do
    user = user_fixture()
    scope = %Fittrack.Accounts.Scope{user: user}
    food_fixture(scope)

    conn = log_in_user(conn, user)
    {:ok, view, _} = live(conn, ~p"/meal-plans/new")

    assert has_element?(view, "#meal-plan-form")

    {:ok, _redirected_view, redirected_html} =
      view
      |> form("#meal-plan-form", %{
        "meal_plan" => %{
          "name" => "Weekly",
          "goal" => "maintain",
          "daily_calories_target" => 2200
        }
      })
      |> render_submit()
      |> follow_redirect(conn, ~p"/meal-plans")

    assert redirected_html =~ "Meal plan created successfully"
    assert redirected_html =~ "Weekly"
  end

  test "workout history shows calendar and counts", %{conn: conn} do
    user = user_fixture()
    conn = log_in_user(conn, user)

    {:ok, _view, html} = live(conn, ~p"/workout-history")
    assert html =~ "Workout History"
    assert html =~ "Month"
  end
end
