defmodule Routemaster.UtilsSpec do
  use ESpec, async: true
  alias Routemaster.Utils

  describe "now()" do
    it "returns a unix timestamp" do
      expect Utils.now() |> to(be_integer())

      correct = DateTime.utc_now()
      {:ok, dt} = DateTime.from_unix(Utils.now())

      expect dt.year       |> to(eq correct.year)
      expect dt.month      |> to(eq correct.month)
      expect dt.day        |> to(eq correct.day)
      expect dt.hour       |> to(eq correct.hour)
      expect dt.minute     |> to(eq correct.minute)
      expect dt.second     |> to(eq correct.second)
      expect dt.utc_offset |> to(eq correct.utc_offset)
    end
  end
end
