{:ok, _} = Application.ensure_all_started(:wallaby)
Application.put_env(:wallaby, :base_url, ShinkankiWebWeb.Endpoint.url())

ExUnit.start(exclude: [:feature])
