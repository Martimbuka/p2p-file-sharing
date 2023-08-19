defmodule P2PFileSharing.MiniServer do
  @moduledoc """
  This module is responsible for handling the client's requests.
  The clients communicate with each other using the MiniServer module.
  """

  @chunk_size 1024

  @doc """
  Starts the MiniServer.
  Opens a socket and listens for incoming connections.
  """
  @spec start(String.t(), non_neg_integer()) :: {:ok, pid()}
  def start(ip, port) do
    {:ok, listen_sock} =
      :gen_tcp.listen(port, [:binary, {:packet, :line}, {:reuseaddr, true}])

    IO.puts("Listening on #{ip}:#{port}")

    loop_accept(listen_sock)
  end

  @spec stop(pid()) :: :ok
  def stop(listen_sock) do
    :gen_tcp.close(listen_sock)
  end

  @spec loop_accept(pid()) :: :ok
  defp loop_accept(listen_sock) do
    {:ok, socket} = :gen_tcp.accept(listen_sock)

    Task.start(fn -> handle_client(socket) end)

    loop_accept(listen_sock)
  end

  @spec handle_client(pid()) :: :ok
  defp handle_client(socket) do
    {:ok, {user, file_path}} = :gen_tcp.recv(socket, 0)

    case Enum.member?(P2PFileSharing.Server.get_files(user), file_path) do
      true ->
        send_file(socket, file_path)

      false ->
        :gen_tcp.send(socket, "File not found")
        :gen_tcp.close(socket)
    end
  end

  @spec send_file(pid(), String.t()) :: :ok
  defp send_file(socket, file_path) do
    File.stream!(file_path, [], @chunk_size)
    |> Enum.each(fn chunk ->
      :gen_tcp.send(socket, chunk)
    end)

    :gen_tcp.close(socket)
  end
end
