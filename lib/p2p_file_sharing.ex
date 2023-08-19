defmodule P2PFileSharing.Application do
  use Application

  def start(_type, _args) do
    P2PFileSharing.Server.start_link([])
  end
end
