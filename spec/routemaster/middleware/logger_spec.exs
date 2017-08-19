defmodule Routemaster.Middleware.LoggerSpec do
  use ESpec, async: true

  alias Routemaster.Middleware.Logger, as: MidLogger

  before do
    original_log_level = Logger.level
    Logger.configure(level: :info)
    {:shared, original_log_level: original_log_level}
  end

  finally do
    Logger.configure(level: shared.original_log_level)
  end


  let :req_url, do: "https://localhost/hamsters/1"
  let :name, do: "TestName"

  let(:req_env) do
    %Tesla.Env{
      url: req_url(),
      method: :get
    }
  end

  let(:resp_env) do
    %Tesla.Env{
      url: req_url(),
      status: 200,
      method: :get
    }
  end

  # The next element of the Tesla stack. It represents an HTTP request.
  let :terminator do
    {:fn, fn(_env) -> resp_env() end}
  end

  subject MidLogger.call(req_env(), [terminator()], [context: name()])

  it "logs the outgoing requests" do
    message = capture_log fn -> subject() end
    regex = ~r{\[#{name()}\] GET #{req_url()} \-\> 200 \(\d+\.\d+ms\)}

    expect message |> to(match regex)
  end

  context "if a Tesla exception is raised" do
    let :terminator do
      {:fn, fn(_env) -> raise Tesla.Error, "a test exception" end}
    end

    it "logs the exception message" do
      message = capture_log fn ->
        try do
          subject()
        rescue
          _ -> nil
        end
      end
      regex = ~r{\[#{name()}\] GET #{req_url()} \-\> a test exception}

      expect message |> to(match regex)
    end
  end
end
