defmodule LvNewAppWeb.ThermostatLive do
  use LvNewAppWeb, :live_view
  use PrintDecorator

  @decorate print()
  def render(assigns) do
    ~H"""
    Current temperature: 155.0
    """
  end

  def mount(_params, _, socket) do
    {:ok, socket}
  end
end
