defmodule Hex do
  @default_url "https://hex.pm"
  @default_cdn "http://s3.hex.pm"


  def start do
    start_api()
    start_mix()
  end

  def start_api do
    :ssl.start()
    :inets.start()

    if url = System.get_env("HEX_URL"), do: url(url)
    if cdn = System.get_env("HEX_CDN"), do: cdn(cdn)
  end

  def start_mix do
    Mix.SCM.append(Hex.SCM)
    Mix.RemoteConverger.register(Hex.RemoteConverger)
  end

  def stop do
    Hex.Registry.stop
  end

  def url do
    case :application.get_env(:hex, :url) do
      { :ok, url } -> url
      :undefined   -> @default_url
    end
  end

  def url(url) do
    url = String.rstrip(url, ?/)
    :application.set_env(:hex, :url, url)
  end

  def cdn do
    case :application.get_env(:hex, :cdn) do
      { :ok, cdn } -> cdn
      :undefined   -> @default_cdn
    end
  end

  def cdn(cdn) do
    cdn = String.rstrip(cdn, ?/)
    :application.set_env(:hex, :cdn, cdn)
  end

  version = Mix.project[:version]
  { :ok, Version.Schema[pre: pre] } = Version.parse(version)
  channel = if pre == ["dev"], do: :dev, else: :stable

  def version, do: unquote(version)
  def channel, do: unquote(channel)
end
