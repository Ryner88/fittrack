defmodule Fittrack.NutritionTest do
  use Fittrack.DataCase

  alias Fittrack.Nutrition

  import Fittrack.AccountsFixtures
  import Fittrack.NutritionFixtures

  describe "foods" do
    setup do
      original_client = Application.get_env(:fittrack, :barcode_lookup_http_client)
      original_response = Application.get_env(:fittrack, :barcode_lookup_test_response)
      original_url_client = Application.get_env(:fittrack, :url_import_http_client)
      original_url_response = Application.get_env(:fittrack, :url_import_test_response)

      original_screenshot_client =
        Application.get_env(:fittrack, :screenshot_import_parser_client)

      original_screenshot_response =
        Application.get_env(:fittrack, :screenshot_import_test_response)

      Application.put_env(
        :fittrack,
        :barcode_lookup_http_client,
        Fittrack.BarcodeLookupClientStub
      )

      Application.put_env(
        :fittrack,
        :url_import_http_client,
        Fittrack.UrlImportHttpClientStub
      )

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

    test "create/get food" do
      scope = user_scope_fixture()
      food = food_fixture(scope)

      assert Nutrition.get_food!(scope, food.id).id == food.id
      assert food.name == "Apple"
    end

    test "list_foods returns only user food" do
      scope = user_scope_fixture()
      food_fixture(scope)
      assert [%{}] = Nutrition.list_foods(scope)
    end

    test "lookup_food_by_barcode normalizes imported nutrition" do
      Application.put_env(:fittrack, :barcode_lookup_test_response, {
        :ok,
        %{
          status: 200,
          body: %{
            "status" => 1,
            "product" => %{
              "product_name" => "Protein Bar",
              "serving_size" => "60 g",
              "nutriments" => %{
                "energy-kcal_100g" => 400,
                "proteins_100g" => 30,
                "carbohydrates_100g" => 35,
                "fat_100g" => 12
              }
            }
          }
        }
      })

      assert {:ok, attrs} = Nutrition.lookup_food_by_barcode("1234567890123")
      assert attrs["name"] == "Protein Bar"
      assert attrs["unit"] == "g"
      assert attrs["unit_amount"] == "100"
      assert attrs["quantity"] == "100"
      assert attrs["calories_per_unit"] == "400"
      assert attrs["protein_per_unit"] == "30"
      assert attrs["carbs_per_unit"] == "35"
      assert attrs["fats_per_unit"] == "12"
    end

    test "import_food_from_url parses supported dining page JSON-LD" do
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

      assert {:ok, attrs} =
               Nutrition.import_food_from_url(
                 "https://www.mcdonalds.com/us/en-us/product/mcdouble.html"
               )

      assert attrs["name"] == "McDouble"
      assert attrs["unit"] == "serving"
      assert attrs["unit_amount"] == "1"
      assert attrs["calories_per_unit"] == "390"
      assert attrs["protein_per_unit"] == "22"
      assert attrs["carbs_per_unit"] == "33"
      assert attrs["fats_per_unit"] == "18"
    end

    test "import_food_from_screenshot normalizes extended nutrients" do
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
              "protein_per_unit" => "Protein 28g"
            }
          }
        }
      })

      assert {:ok, attrs} =
               Nutrition.import_food_from_screenshot("data:image/png;base64,abc123", %{
                 "source" => "upload",
                 "filename" => "turkey-sandwich.png",
                 "mime_type" => "image/png"
               })

      assert attrs["name"] == "Turkey Sandwich"
      assert attrs["fiber_per_unit"] == "5"
      assert attrs["sodium_mg_per_unit"] == "870"
      assert attrs["micronutrients_text"] =~ "Potassium: 420 mg"
      assert attrs["source_image_metadata"]["filename"] == "turkey-sandwich.png"
      assert attrs["parsed_values"]["venue_name"] == "North Dining Hall"
      assert attrs["parsed_values"]["detected_context"]["kind"] == "dining_hall_modal"
      assert attrs["parsed_values"]["field_mapping"]["calories_per_unit"] == "Calories 420"
      assert "Turkey Sandwich" in attrs["parsed_values"]["extracted_text"]
    end

    test "create_food stores parsed screenshot metadata" do
      scope = user_scope_fixture()

      attrs =
        Nutrition.barcode_food_defaults(%{
          "name" => "Dining Hall Chili",
          "unit" => "serving",
          "unit_amount" => "1",
          "quantity" => "1",
          "calories_per_unit" => "310",
          "protein_per_unit" => "18",
          "carbs_per_unit" => "24",
          "fats_per_unit" => "14",
          "source_image_metadata" => %{
            "source" => "clipboard",
            "mime_type" => "image/png",
            "byte_size" => 24_000
          },
          "parsed_values" => %{
            "detected_context" => %{"kind" => "dining_hall_modal"},
            "field_mapping" => %{"calories_per_unit" => "Calories 310"},
            "extracted_text" => ["Dining Hall Chili", "Calories 310"]
          }
        })

      assert {:ok, food} = Nutrition.create_food(scope, attrs)
      assert food.source_image_metadata["source"] == "clipboard"
      assert food.parsed_values["detected_context"]["kind"] == "dining_hall_modal"
    end
  end

  describe "meals" do
    test "create meal calculates totals" do
      scope = user_scope_fixture()

      meal = meal_fixture(scope)
      assert meal.total_calories == Decimal.new("52")
      assert has = Enum.any?(meal.meal_items, fn i -> i.food_name == "Apple" end)
      assert has
    end

    test "create meal stores import metadata on meal items" do
      scope = user_scope_fixture()

      assert {:ok, meal} =
               Nutrition.create_meal(scope, %{
                 "name" => "Campus Lunch",
                 "eaten_at" => DateTime.utc_now(),
                 "meal_items" => [
                   %{
                     "food_name" => "Dining Hall Pasta",
                     "quantity" => "1",
                     "unit" => "serving",
                     "calories" => "560",
                     "protein_g" => "21",
                     "carbs_g" => "69",
                     "fats_g" => "22",
                     "source_image_metadata" => %{
                       "source" => "upload",
                       "mime_type" => "image/png"
                     },
                     "parsed_values" => %{
                       "detected_context" => %{"kind" => "dining_hall_modal"},
                       "field_mapping" => %{"calories" => "Calories 560"},
                       "extracted_text" => ["Dining Hall Pasta", "Calories 560"]
                     }
                   }
                 ]
               })

      [item] = meal.meal_items
      assert item.source_image_metadata["source"] == "upload"
      assert item.parsed_values["field_mapping"]["calories"] == "Calories 560"
    end

    test "meal CRUD supports update, list, get, and delete" do
      scope = user_scope_fixture()
      meal = meal_fixture(scope)

      assert [listed_meal] = Nutrition.list_meals(scope)
      assert listed_meal.id == meal.id
      assert Nutrition.get_meal!(scope, meal.id).name == "Test Meal"

      assert {:ok, updated_meal} =
               Nutrition.update_meal(scope, meal, %{"name" => "Updated Meal"})

      assert updated_meal.name == "Updated Meal"
      assert {:ok, _deleted_meal} = Nutrition.delete_meal(scope, updated_meal)
      assert Nutrition.list_meals(scope) == []
    end
  end

  describe "meal plans" do
    test "create meal plan with meals works" do
      scope = user_scope_fixture()
      plan = meal_plan_fixture(scope)

      assert plan.name == "Weekly plan"
      assert length(plan.meal_plan_meals) == 1
    end

    test "meal plan CRUD supports update, list, get, and delete" do
      scope = user_scope_fixture()
      plan = meal_plan_fixture(scope)

      assert [listed_plan] = Nutrition.list_meal_plans(scope)
      assert listed_plan.id == plan.id
      assert Nutrition.get_meal_plan!(scope, plan.id).name == "Weekly plan"

      assert {:ok, updated_plan} =
               Nutrition.update_meal_plan(scope, plan, %{"name" => "Updated plan"})

      assert updated_plan.name == "Updated plan"
      assert {:ok, _deleted_plan} = Nutrition.delete_meal_plan(scope, updated_plan)
      assert Nutrition.list_meal_plans(scope) == []
    end
  end
end
