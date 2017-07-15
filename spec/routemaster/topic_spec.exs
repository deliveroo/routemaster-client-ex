defmodule Routemaster.TopicSpec do
  use ESpec, async: true
  alias Routemaster.Topic

  describe "valid_name?" do
    it "returns true for valid names" do
      assert Topic.valid_name?("avocados")

      long_name = Enum.map(1..64, fn(_i)-> "a" end) |> Enum.join
      assert Topic.valid_name?(long_name)
    end


    it "returns false for invalid names" do
      refute Topic.valid_name?("avocados2")
      refute Topic.valid_name?("avocados hello")
      refute Topic.valid_name?("Avocados")
      refute Topic.valid_name?("")
      refute Topic.valid_name?("avocados2")

      long_name = Enum.map(1..65, fn(_i)-> "a" end) |> Enum.join
      refute Topic.valid_name?(long_name)
    end
  end


  describe "validate_name!" do
    it "returns nil for valid names" do
      expect Topic.validate_name!("avocados") |> to(be_nil())

      long_name = Enum.map(1..64, fn(_i)-> "a" end) |> Enum.join
      expect Topic.validate_name!(long_name) |> to(be_nil())
    end


    it "raises an exception for invalid names" do
      error_type = Routemaster.Topic.InvalidNameError

      expect fn() -> Topic.validate_name!("avocados2") end |> to(raise_exception error_type)
      expect fn() -> Topic.validate_name!("avocados hello") end |> to(raise_exception error_type)
      expect fn() -> Topic.validate_name!("Avocados") end |> to(raise_exception error_type)
      expect fn() -> Topic.validate_name!("") end |> to(raise_exception error_type)
      expect fn() -> Topic.validate_name!("avocados2") end |> to(raise_exception error_type)

      long_name = Enum.map(1..65, fn(_i)-> "a" end) |> Enum.join
      expect fn() -> Topic.validate_name!(long_name) end |> to(raise_exception error_type)
    end
  end
end
