defmodule TTRSS.Account do
  alias __MODULE__
  alias TTRSS.Client

  @enforce_keys [:api_url, :username, :password, :output_dir]
  defstruct api_url: nil,
            username: nil,
            password: nil,
            output_dir: nil,
            sid: nil

  def new!(account = %{}) do
    new(
      Map.fetch!(account, "api"),
      Map.fetch!(account, "username"),
      Map.fetch!(account, "password"),
      Map.fetch!(account, "output")
    )
  end

  def new(api_url, username, password, output_dir) do
    %Account{
      api_url: api_url,
      username: username,
      password: password,
      output_dir: output_dir
    }
  end

  def login(account) do
    {:ok, sid} = Client.login(account.api_url, account.username, account.password)
    %Account{account | sid: sid}
  end
end
