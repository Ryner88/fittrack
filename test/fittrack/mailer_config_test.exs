defmodule Fittrack.MailerConfigTest do
  use ExUnit.Case, async: false

  @runtime_config Path.expand("../../config/runtime.exs", __DIR__)
  @test_config Path.expand("../../config/test.exs", __DIR__)

  setup do
    variables = %{
      "DATABASE_URL" => "ecto://test:test@localhost/fittrack_config_test",
      "SECRET_KEY_BASE" => String.duplicate("test", 16),
      "RESEND_API_KEY" => "test-resend-key",
      "PORT" => "4000",
      "POOL_SIZE" => "10"
    }

    previous = Map.new(variables, fn {key, _value} -> {key, System.get_env(key)} end)
    System.put_env(variables)

    on_exit(fn ->
      Enum.each(previous, fn
        {key, nil} -> System.delete_env(key)
        {key, value} -> System.put_env(key, value)
      end)
    end)

    :ok
  end

  test "production selects Resend and reads its runtime API key" do
    config = Config.Reader.read!(@runtime_config, env: :prod)
    mailer = config[:fittrack][Fittrack.Mailer]

    assert mailer[:adapter] == Swoosh.Adapters.Resend
    assert mailer[:api_key] == "test-resend-key"
    assert config[:swoosh][:api_client] == Swoosh.ApiClient.Req
  end

  test "production fails clearly when RESEND_API_KEY is missing" do
    System.delete_env("RESEND_API_KEY")

    assert_raise System.EnvError, ~r/RESEND_API_KEY/, fn ->
      Config.Reader.read!(@runtime_config, env: :prod)
    end
  end

  test "test runtime keeps the test adapter and disables the external API client" do
    config =
      Config.Reader.merge(
        Config.Reader.read!(@test_config, env: :test),
        Config.Reader.read!(@runtime_config, env: :test)
      )

    assert config[:fittrack][Fittrack.Mailer][:adapter] == Swoosh.Adapters.Test
    assert config[:swoosh][:api_client] == false

    assert Application.fetch_env!(:fittrack, Fittrack.Mailer)[:adapter] ==
             Swoosh.Adapters.Test

    assert Application.fetch_env!(:swoosh, :api_client) == false
  end
end
