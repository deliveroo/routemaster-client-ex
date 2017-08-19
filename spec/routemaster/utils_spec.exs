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


  describe "valid_url?" do
    it "returns true with a valid HTTPS URL" do
      assert Utils.valid_url?("https://foo.bar")
    end

    it "returns false with a valid HTTP URL" do
      refute Utils.valid_url?("http://foo.bar")
    end

    it "returns false with a non-HTTP(S) URL" do
      refute Utils.valid_url?("ftp://foo.bar")
      refute Utils.valid_url?("foo.bar")
      refute Utils.valid_url?("")
    end
  end

  describe "build_auth_header(username, password)" do
    let :username, do: "I know this!"
    let :password, do: "It's a Unix system!"

    before do
      token = Base.encode64("#{username()}:#{password()}")
      {:shared, token: token}
    end

    it "returns a Authentication HTTP header value" do
      expect Utils.build_auth_header(username(), password())
      |> to(eq "Basic #{shared.token}")
    end
  end


  describe "debug_message(title, message, color)" do
    subject(
      Utils.debug_message("foo", "bar baz", :magenta)
    )

    let :io_list do
      [[[[[[[[[[] | "\e[35m"] | "\e[1m"], "["], "foo"], "]"] | "\e[22m"], 32], "bar baz"] | "\e[0m"]
    end

    it "returns a IO list" do
      expect subject() |> to(eq io_list())
    end

    specify "the returned IO list can be used as a shell escaped string" do
      expect IO.iodata_to_binary(subject())
      |> to(eq "\e[35m\e[1m[foo]\e[22m bar baz\e[0m")
    end
  end
end
