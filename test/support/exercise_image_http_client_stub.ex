defmodule Fittrack.ExerciseImageHttpClientStub do
  def get(url, _opts) do
    send(self(), {:exercise_image_request, url})

    response =
      Application.get_env(:fittrack, :exercise_image_test_response, {
        :ok,
        %{status: 200, body: "fake-image", headers: [{"content-type", "image/jpeg"}]}
      })

    response
  end
end
