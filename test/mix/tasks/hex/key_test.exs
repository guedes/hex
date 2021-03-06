defmodule Mix.Tasks.Hex.KeyTest do
  use HexTest.Case
  @moduletag :integration

  test "new key" do
    in_tmp fn _ ->
      System.put_env("MIX_HOME", System.cwd!)
      Mix.Tasks.Hex.Key.New.run(["-u", "user", "-p", "hunter42"])

      { :ok, name } = :inet.gethostname()
      name = String.from_char_list!(name)
      user = HexWeb.User.get("user")
      key = HexWeb.API.Key.get(name, user)

      assert Hex.Mix.read_config[:username] == "user"
      assert Hex.Mix.read_config[:key] == key.secret
    end
  after
    System.delete_env("MIX_HOME")
  end

  test "list keys" do
    user = HexWeb.User.get("user")
    HexWeb.API.Key.create("list_keys", user)

    Mix.Tasks.Hex.Key.List.run(["-u", "user", "-p", "hunter42"])
    assert_received { :mix_shell, :info, ["list_keys"] }
  end

  test "drop key" do
    user = HexWeb.User.get("user")
    HexWeb.API.Key.create("drop_key", user)

    Mix.Tasks.Hex.Key.Drop.run(["drop_key", "-u", "user", "-p", "hunter42"])

    assert_received { :mix_shell, :info, ["Dropping key drop_key..."] }
    refute HexWeb.API.Key.get("drop_key", user)
  end
end
