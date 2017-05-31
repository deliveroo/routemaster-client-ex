defmodule RoutemasterSpec do
  use ESpec

  doctest Routemaster

  it "passes with the truth" do
    expect true |> to(be_true())
  end
end
