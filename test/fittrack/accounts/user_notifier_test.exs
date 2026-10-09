defmodule Fittrack.Accounts.UserNotifierTest do
  use ExUnit.Case, async: true

  import Swoosh.TestAssertions

  alias Fittrack.Accounts.{User, UserNotifier}

  test "confirmation instructions use the production sender and requested recipient" do
    user = %User{email: "recipient@example.com", confirmed_at: nil}
    url = "https://example.com/confirm/test-token"

    assert {:ok, email} = UserNotifier.deliver_login_instructions(user, url)
    assert_email(email, user.email, "Confirmation instructions", url)
  end

  test "confirmed users receive magic link instructions from the production sender" do
    user = %User{email: "recipient@example.com", confirmed_at: ~U[2026-01-01 00:00:00Z]}
    url = "https://example.com/login/test-token"

    assert {:ok, email} = UserNotifier.deliver_login_instructions(user, url)
    assert_email(email, user.email, "Log in instructions", url)
  end

  test "email update instructions use the production sender and new recipient" do
    user = %User{email: "new-recipient@example.com"}
    url = "https://example.com/update-email/test-token"

    assert {:ok, email} = UserNotifier.deliver_update_email_instructions(user, url)
    assert_email(email, user.email, "Update email instructions", url)
  end

  defp assert_email(email, recipient, subject, url) do
    assert email.from == {"Fittrack", "noreply@fittrackweb.cloud"}
    assert email.to == [{"", recipient}]
    assert email.subject == subject
    assert email.text_body =~ url
    assert_email_sent(email)
  end
end
