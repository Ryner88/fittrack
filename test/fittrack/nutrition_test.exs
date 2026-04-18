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
          "micronutrients" => %{"Potassium" => "420 mg", "Calcium" => "120 mg"}
        }
      })

      assert {:ok, attrs} = Nutrition.import_food_from_screenshot("data:image/png;base64,abc123")
      assert attrs["name"] == "Turkey Sandwich"
      assert attrs["fiber_per_unit"] == "5"
      assert attrs["sodium_mg_per_unit"] == "870"
      assert attrs["micronutrients_text"] =~ "Potassium: 420 mg"
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
  end

  describe "meal plans" do
    test "create meal plan with meals works" do
      scope = user_scope_fixture()
      plan = meal_plan_fixture(scope)

      assert plan.name == "Weekly plan"
      assert length(plan.meal_plan_meals) == 1
    end
  end
end
