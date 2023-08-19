defmodule P2PFileSharing.Client do
  @moduledoc """
  This module is responsible for handling the client's requests.
  The client can register files, unregister files, list files, download files from peers.
  The client uses the MiniServer module to download files from peers.
  """
  alias P2PFileSharing.Server
  alias P2PFileSharing.MiniServer

  @chunk_size 1024
  # every 30 seconds
  @refresh_interval 30_000
  @base_port 4040
  @local_ip "127.0.0.1"

  @doc """
  Starts the client. The client starts the MiniServer and registers itself with the server.
  It also creates a unique port for the MiniServer.
  """
  @spec start(String.t()) :: :ok
  def start(client_name) do
    port = create_unique_port()
    MiniServer.start(@local_ip, port)
    Server.add_user(client_name, @local_ip, port)
  end

  @doc """
  Stops the client. The client stops the MiniServer and unregisters itself with the server.
  """
  @spec stop(String.t()) :: :ok
  def stop(client_name) do
    port = Server.get_port(client_name)
    MiniServer.stop(port)
    Server.remove_user(client_name)
  end

  @doc """
  Requests the server for the list of files that are shared by the users.
  """
  @spec request_files_details() :: [{String.t(), String.t(), String.t(), non_neg_integer()}] | :error
  def request_files_details() do
    P2PFileSharing.Server.list_files()
  end

  @doc """
  Requests the server for the list of files that are shared by the user.
  """
  @spec request_files_details(String.t()) :: [String.t()] | :error
  def request_files_details(user) do
    P2PFileSharing.Server.get_files(user)
  end

  @doc """
  Requests the server to register the files that are shared by the user.
  """
  @spec register(String.t(), String.t(), String.t(), non_neg_integer()) :: :ok | {:error, String.t()}
  def register(user, files, ip, port) do
    case Server.register(user, files, ip, port) do
      :ok ->
        IO.puts("Successfully registered files with the server.")

      {:error, reason} ->
        IO.puts("Failed to register due to: #{reason}")
    end
  end

  @doc """
  Requests the server to unregister the files that are shared by the user.
  """
  @spec unregister(String.t(), String.t()) :: :ok | {:error, String.t()}
  def unregister(user, files) do
    case Server.unregister(user, files) do
      :ok ->
        IO.puts("Successfully unregistered files with the server.")

      {:error, reason} ->
        IO.puts("Failed to unregister due to: #{reason}")
    end
  end

 @doc """
  Returns a list of all the files that are shared by all the users.
  Format: [{user, [file1, file2, ...], ip, port}, ...]
  """
  @spec list_files() :: [FileInfo.t()]
  def list_files() do
    files = Server.list_files()
    IO.puts(format_files(files))
  end

  @doc """
  Creates a unique port for the MiniServer.
  Uses loop_port/2 to find a unique port. If a port is taken, it increments the port by 1.
  """
  @spec create_unique_port() :: non_neg_integer() | :error
  def create_unique_port() do
    info = Server.list_files()
    port = @base_port
    ports = Enum.map(info, fn {_, _, _, port} -> port end)
    loop_port(ports, port)

    port
  end

  @spec loop_port([non_neg_integer()], non_neg_integer()) :: non_neg_integer() | :error
  defp loop_port(ports, port) do
    case Enum.member?(ports, port) do
      true ->
        loop_port(ports, port + 1)

      false ->
        cond do
          port > 65535 ->
            IO.puts("No available port found.")
            :error

          true ->
            port
        end
    end
  end

  def download_file_from_peer(peer, {user, file_path}, save_path) do
    {:ok, socket} =
      :gen_tcp.connect(peer.host, peer.port, [:binary, {:packet, 0}, {:active, false}])

    :gen_tcp.send(socket, {user, file_path})

    receive do
      {:tcp, ^socket, "File not found"} ->
        IO.puts("File not found on peer. Please try again.")
        :gen_tcp.close(socket)
        :error

      {:tcp, ^socket, _} ->
        save_file(socket, save_path)
    after
      5000 ->
        IO.puts("Connection timed out.")
        :gen_tcp.close(socket)
        :error
    end
  end

  # Private functions

  defp save_file(socket, save_path) do
    File.open(save_path, [:binary, :write], fn file ->
      loop_recv(socket, file)
    end)
  end

  defp loop_recv(socket, file) do
    case :gen_tcp.recv(socket, @chunk_size) do
      {:ok, data} ->
        IO.binwrite(file, data)
        loop_recv(socket, file)

      {:error, :closed} ->
        IO.puts("File download completed!")
        :ok

      {:error, reason} ->
        IO.puts("Failed to receive data: #{reason}")
        :error
    end
  end

  defp format_files(files) do
    Enum.map_join(files, "\n", fn {user, file_path, _, _} ->
      "#{user} - #{file_path}"
    end)
  end
end
