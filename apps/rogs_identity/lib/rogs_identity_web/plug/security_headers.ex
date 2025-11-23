defmodule RogsIdentityWeb.Plug.SecurityHeaders do
  @moduledoc """
  Adds security headers to responses.

  This plug adds common security headers to help protect against
  various attacks including XSS, clickjacking, and MIME type sniffing.
  """

  import Plug.Conn

  @behaviour Plug

  def init(opts), do: opts

  def call(conn, _opts) do
    conn
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("x-frame-options", "DENY")
    |> put_resp_header("x-xss-protection", "1; mode=block")
    |> put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
  end
end
